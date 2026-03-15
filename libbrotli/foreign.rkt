#lang racket/base

(require (for-syntax racket/base)
         ffi/unsafe
         ffi/unsafe/define
         racket/runtime-path)

(provide
 brotli-compress!
 brotli-decompress!
 brotli-compress
 brotli-decompress)

;; Brotli ships as three shared libraries: common, encoder, decoder.
;; The encoder and decoder both depend on common, so we load common first.
(define-runtime-path libbrotlicommon.so
  '(so "libbrotlicommon"))
(define-runtime-path libbrotlienc.so
  '(so "libbrotlienc"))
(define-runtime-path libbrotlidec.so
  '(so "libbrotlidec"))

;; Load common first so enc/dec can resolve their symbols against it.
(define libbrotlicommon (ffi-lib libbrotlicommon.so))
(define-ffi-definer define-brotli-enc (ffi-lib libbrotlienc.so))
(define-ffi-definer define-brotli-dec (ffi-lib libbrotlidec.so))

;; Encoder constants
(define BROTLI_DEFAULT_QUALITY 11)
(define BROTLI_DEFAULT_WINDOW 22)
(define BROTLI_MODE_GENERIC 0)

;; Decoder result codes
(define BROTLI_DECODER_RESULT_ERROR 0)
(define BROTLI_DECODER_RESULT_SUCCESS 1)
(define BROTLI_DECODER_RESULT_NEEDS_MORE_INPUT 2)
(define BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT 3)

;; ---- Encoder FFI ----

;; BROTLI_BOOL BrotliEncoderCompress(
;;   int quality, int lgwin, BrotliEncoderMode mode,
;;   size_t input_size, const uint8_t* input_buffer,
;;   size_t* encoded_size, uint8_t* encoded_buffer)
(define-brotli-enc BrotliEncoderCompress
  (_fun _int _int _int _size _bytes _pointer _bytes -> _int))

;; size_t BrotliEncoderMaxCompressedSize(size_t input_size)
(define-brotli-enc BrotliEncoderMaxCompressedSize
  (_fun _size -> _size))

;; ---- Decoder FFI ----

;; BrotliDecoderState* BrotliDecoderCreateInstance(
;;   brotli_alloc_func, brotli_free_func, void* opaque)
(define-brotli-dec BrotliDecoderCreateInstance
  (_fun _pointer _pointer _pointer -> _pointer))

;; void BrotliDecoderDestroyInstance(BrotliDecoderState* state)
(define-brotli-dec BrotliDecoderDestroyInstance
  (_fun _pointer -> _void))

;; BrotliDecoderResult BrotliDecoderDecompressStream(
;;   BrotliDecoderState* state,
;;   size_t* available_in, const uint8_t** next_in,
;;   size_t* available_out, uint8_t** next_out,
;;   size_t* total_out)
(define-brotli-dec BrotliDecoderDecompressStream
  (_fun _pointer _pointer _pointer _pointer _pointer _pointer -> _int))

;; BrotliDecoderErrorCode BrotliDecoderGetErrorCode(BrotliDecoderState* state)
(define-brotli-dec BrotliDecoderGetErrorCode
  (_fun _pointer -> _int))

;; const char* BrotliDecoderErrorString(BrotliDecoderErrorCode c)
(define-brotli-dec BrotliDecoderErrorString
  (_fun _int -> _string))

;; ---- Helpers ----

(define (brotli-compress! src dst [quality BROTLI_DEFAULT_QUALITY])
  (define encoded-size-ptr (malloc _size 'atomic))
  (ptr-set! encoded-size-ptr _size (bytes-length dst))
  (define ok
    (BrotliEncoderCompress
     quality BROTLI_DEFAULT_WINDOW BROTLI_MODE_GENERIC
     (bytes-length src) src
     encoded-size-ptr dst))
  (when (zero? ok)
    (error 'brotli-compress! "compression failed"))
  (ptr-ref encoded-size-ptr _size))

(define (brotli-decompress! src dst)
  (define state (BrotliDecoderCreateInstance #f #f #f))
  (unless state
    (error 'brotli-decompress! "failed to create decoder instance"))
  (dynamic-wind
    void
    (lambda ()
      (define avail-in-ptr (malloc _size 'atomic))
      (define next-in-ptr (malloc _pointer 'atomic))
      (define avail-out-ptr (malloc _size 'atomic))
      (define next-out-ptr (malloc _pointer 'atomic))
      (define total-out-ptr (malloc _size 'atomic))
      (ptr-set! avail-in-ptr _size (bytes-length src))
      (ptr-set! next-in-ptr _pointer src)
      (ptr-set! avail-out-ptr _size (bytes-length dst))
      (ptr-set! next-out-ptr _pointer dst)
      (ptr-set! total-out-ptr _size 0)
      (define result
        (BrotliDecoderDecompressStream
         state avail-in-ptr next-in-ptr avail-out-ptr next-out-ptr total-out-ptr))
      (cond
        [(= result BROTLI_DECODER_RESULT_SUCCESS)
         (ptr-ref total-out-ptr _size)]
        [(= result BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT)
         (error 'brotli-decompress! "output buffer too small")]
        [(= result BROTLI_DECODER_RESULT_NEEDS_MORE_INPUT)
         (error 'brotli-decompress! "input is incomplete")]
        [else
         (define code (BrotliDecoderGetErrorCode state))
         (define msg (BrotliDecoderErrorString code))
         (error 'brotli-decompress! "decompression failed: ~a" msg)]))
    (lambda ()
      (BrotliDecoderDestroyInstance state))))

(define (brotli-compress src [quality BROTLI_DEFAULT_QUALITY])
  (define bound (BrotliEncoderMaxCompressedSize (bytes-length src)))
  (when (zero? bound)
    (error 'brotli-compress "input too large"))
  (define dst (make-bytes bound))
  (subbytes dst 0 (brotli-compress! src dst quality)))

(define (brotli-decompress src [max-decompressed-size #f])
  ;; Brotli streams do not embed the decompressed size, so we use
  ;; streaming decompression with a growing buffer.
  (define state (BrotliDecoderCreateInstance #f #f #f))
  (unless state
    (error 'brotli-decompress "failed to create decoder instance"))
  (dynamic-wind
    void
    (lambda ()
      (define avail-in-ptr (malloc _size 'atomic))
      (define next-in-ptr (malloc _pointer 'atomic))
      (define avail-out-ptr (malloc _size 'atomic))
      (define next-out-ptr (malloc _pointer 'atomic))
      (define total-out-ptr (malloc _size 'atomic))
      (ptr-set! avail-in-ptr _size (bytes-length src))
      (ptr-set! next-in-ptr _pointer src)
      (ptr-set! total-out-ptr _size 0)
      ;; Start with a buffer the same size as input (reasonable guess).
      ;; Grow by doubling when NEEDS_MORE_OUTPUT.
      (let loop ([buf (make-bytes (max 256 (bytes-length src)))]
                 [offset 0])
        (when (and max-decompressed-size (> (bytes-length buf) max-decompressed-size))
          (set! buf (subbytes buf 0 max-decompressed-size)))
        (define remaining (- (bytes-length buf) offset))
        (when (and max-decompressed-size (> offset max-decompressed-size))
          (error 'brotli-decompress "decompressed length exceeds max size (~a)" max-decompressed-size))
        ;; We need a pointer into buf at the current offset.
        ;; Use a temporary buffer for this chunk, then copy back.
        (define chunk-buf (make-bytes remaining))
        (ptr-set! avail-out-ptr _size remaining)
        (ptr-set! next-out-ptr _pointer chunk-buf)
        (define result
          (BrotliDecoderDecompressStream
           state avail-in-ptr next-in-ptr avail-out-ptr next-out-ptr total-out-ptr))
        (define written (- remaining (ptr-ref avail-out-ptr _size)))
        (bytes-copy! buf offset chunk-buf 0 written)
        (define new-offset (+ offset written))
        (cond
          [(= result BROTLI_DECODER_RESULT_SUCCESS)
           (subbytes buf 0 new-offset)]
          [(= result BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT)
           (define new-size (* (bytes-length buf) 2))
           (when (and max-decompressed-size (> new-size max-decompressed-size))
             (set! new-size max-decompressed-size))
           (when (<= new-size (bytes-length buf))
             (error 'brotli-decompress "decompressed length exceeds max size (~a)" max-decompressed-size))
           (define new-buf (make-bytes new-size))
           (bytes-copy! new-buf 0 buf 0 new-offset)
           (loop new-buf new-offset)]
          [(= result BROTLI_DECODER_RESULT_NEEDS_MORE_INPUT)
           (error 'brotli-decompress "input is incomplete or corrupted")]
          [else
           (define code (BrotliDecoderGetErrorCode state))
           (define msg (BrotliDecoderErrorString code))
           (error 'brotli-decompress "decompression failed: ~a" msg)])))
    (lambda ()
      (BrotliDecoderDestroyInstance state))))

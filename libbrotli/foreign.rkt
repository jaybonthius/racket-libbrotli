#lang racket/base

(require (for-syntax racket/base)
         ffi/unsafe
         ffi/unsafe/define
         racket/runtime-path)

(provide brotli-compress!
         brotli-decompress!
         brotli-compress
         brotli-decompress
         open-brotli-output
         open-brotli-input
         BROTLI_DEFAULT_QUALITY
         BROTLI_DEFAULT_WINDOW
         BROTLI_MIN_QUALITY
         BROTLI_MAX_QUALITY
         BROTLI_MIN_WINDOW_BITS
         BROTLI_MAX_WINDOW_BITS
         BROTLI_MODE_GENERIC
         BROTLI_MODE_TEXT
         BROTLI_MODE_FONT)

;; Brotli ships as three shared libraries: common, encoder, decoder.
;; The encoder and decoder both depend on common, so we load common first.
(define-runtime-path libbrotlicommon.so '(so "libbrotlicommon"))
(define-runtime-path libbrotlienc.so '(so "libbrotlienc"))
(define-runtime-path libbrotlidec.so '(so "libbrotlidec"))

;; Load common first so enc/dec can resolve their symbols against it.
(define libbrotlicommon (ffi-lib libbrotlicommon.so))
(define-ffi-definer define-brotli-enc (ffi-lib libbrotlienc.so))
(define-ffi-definer define-brotli-dec (ffi-lib libbrotlidec.so))

;; ---- Encoder constants ----

(define BROTLI_MIN_QUALITY 0)
(define BROTLI_MAX_QUALITY 11)
(define BROTLI_DEFAULT_QUALITY 11)
(define BROTLI_MIN_WINDOW_BITS 10)
(define BROTLI_MAX_WINDOW_BITS 24)
(define BROTLI_DEFAULT_WINDOW 22)

;; BrotliEncoderMode
(define BROTLI_MODE_GENERIC 0)
(define BROTLI_MODE_TEXT 1)
(define BROTLI_MODE_FONT 2)

;; BrotliEncoderOperation
(define BROTLI_OPERATION_PROCESS 0)
(define BROTLI_OPERATION_FLUSH 1)
(define BROTLI_OPERATION_FINISH 2)

;; BrotliEncoderParameter
(define BROTLI_PARAM_MODE 0)
(define BROTLI_PARAM_QUALITY 1)
(define BROTLI_PARAM_LGWIN 2)
(define BROTLI_PARAM_LGBLOCK 3)

;; BrotliSharedDictionaryType
(define BROTLI_SHARED_DICTIONARY_RAW 0)

;; ---- Decoder constants ----

(define BROTLI_DECODER_RESULT_ERROR 0)
(define BROTLI_DECODER_RESULT_SUCCESS 1)
(define BROTLI_DECODER_RESULT_NEEDS_MORE_INPUT 2)
(define BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT 3)

;; ---- Encoder FFI ----

;; BROTLI_BOOL BrotliEncoderCompress(
;;   int quality, int lgwin, BrotliEncoderMode mode,
;;   size_t input_size, const uint8_t* input_buffer,
;;   size_t* encoded_size, uint8_t* encoded_buffer)
(define-brotli-enc BrotliEncoderCompress (_fun _int _int _int _size _bytes _pointer _bytes -> _int))

;; size_t BrotliEncoderMaxCompressedSize(size_t input_size)
(define-brotli-enc BrotliEncoderMaxCompressedSize (_fun _size -> _size))

;; ---- Streaming Encoder FFI ----

;; BrotliEncoderState* BrotliEncoderCreateInstance(
;;   brotli_alloc_func, brotli_free_func, void* opaque)
(define-brotli-enc BrotliEncoderCreateInstance (_fun _pointer _pointer _pointer -> _pointer))

;; void BrotliEncoderDestroyInstance(BrotliEncoderState* state)
(define-brotli-enc BrotliEncoderDestroyInstance (_fun _pointer -> _void))

;; BROTLI_BOOL BrotliEncoderSetParameter(
;;   BrotliEncoderState* state, BrotliEncoderParameter param, uint32_t value)
(define-brotli-enc BrotliEncoderSetParameter (_fun _pointer _int _uint32 -> _int))

;; BROTLI_BOOL BrotliEncoderCompressStream(
;;   BrotliEncoderState* state, BrotliEncoderOperation op,
;;   size_t* available_in, const uint8_t** next_in,
;;   size_t* available_out, uint8_t** next_out,
;;   size_t* total_out)
(define-brotli-enc BrotliEncoderCompressStream
                   (_fun _pointer _int _pointer _pointer _pointer _pointer _pointer -> _int))

;; BROTLI_BOOL BrotliEncoderHasMoreOutput(BrotliEncoderState* state)
(define-brotli-enc BrotliEncoderHasMoreOutput (_fun _pointer -> _int))

;; const uint8_t* BrotliEncoderTakeOutput(BrotliEncoderState* state, size_t* size)
(define-brotli-enc BrotliEncoderTakeOutput (_fun _pointer _pointer -> _pointer))

;; BROTLI_BOOL BrotliEncoderIsFinished(BrotliEncoderState* state)
(define-brotli-enc BrotliEncoderIsFinished (_fun _pointer -> _int))

;; ---- Encoder Dictionary FFI ----

;; BrotliEncoderPreparedDictionary* BrotliEncoderPrepareDictionary(
;;   BrotliSharedDictionaryType type, size_t data_size, const uint8_t* data,
;;   int quality, brotli_alloc_func, brotli_free_func, void* opaque)
(define-brotli-enc BrotliEncoderPrepareDictionary
                   (_fun _int _size _bytes _int _pointer _pointer _pointer -> _pointer))

;; void BrotliEncoderDestroyPreparedDictionary(BrotliEncoderPreparedDictionary* dictionary)
(define-brotli-enc BrotliEncoderDestroyPreparedDictionary (_fun _pointer -> _void))

;; BROTLI_BOOL BrotliEncoderAttachPreparedDictionary(
;;   BrotliEncoderState* state, const BrotliEncoderPreparedDictionary* dictionary)
(define-brotli-enc BrotliEncoderAttachPreparedDictionary (_fun _pointer _pointer -> _int))

;; ---- Decoder FFI ----

;; BrotliDecoderState* BrotliDecoderCreateInstance(
;;   brotli_alloc_func, brotli_free_func, void* opaque)
(define-brotli-dec BrotliDecoderCreateInstance (_fun _pointer _pointer _pointer -> _pointer))

;; void BrotliDecoderDestroyInstance(BrotliDecoderState* state)
(define-brotli-dec BrotliDecoderDestroyInstance (_fun _pointer -> _void))

;; BrotliDecoderResult BrotliDecoderDecompressStream(
;;   BrotliDecoderState* state,
;;   size_t* available_in, const uint8_t** next_in,
;;   size_t* available_out, uint8_t** next_out,
;;   size_t* total_out)
(define-brotli-dec BrotliDecoderDecompressStream
                   (_fun _pointer _pointer _pointer _pointer _pointer _pointer -> _int))

;; BrotliDecoderErrorCode BrotliDecoderGetErrorCode(BrotliDecoderState* state)
(define-brotli-dec BrotliDecoderGetErrorCode (_fun _pointer -> _int))

;; const char* BrotliDecoderErrorString(BrotliDecoderErrorCode c)
(define-brotli-dec BrotliDecoderErrorString (_fun _int -> _string))

;; BROTLI_BOOL BrotliDecoderIsFinished(const BrotliDecoderState* state)
(define-brotli-dec BrotliDecoderIsFinished (_fun _pointer -> _int))

;; BROTLI_BOOL BrotliDecoderHasMoreOutput(const BrotliDecoderState* state)
(define-brotli-dec BrotliDecoderHasMoreOutput (_fun _pointer -> _int))

;; const uint8_t* BrotliDecoderTakeOutput(BrotliDecoderState* state, size_t* size)
(define-brotli-dec BrotliDecoderTakeOutput (_fun _pointer _pointer -> _pointer))

;; ---- Decoder Dictionary FFI ----

;; BROTLI_BOOL BrotliDecoderAttachDictionary(
;;   BrotliDecoderState* state, BrotliSharedDictionaryType type,
;;   size_t data_size, const uint8_t* data)
(define-brotli-dec BrotliDecoderAttachDictionary (_fun _pointer _int _size _bytes -> _int))

;; ---- Helpers ----

;; Prepare and attach a dictionary to an encoder state.  Returns the
;; prepared-dictionary pointer (caller must destroy it) or #f when the
;; dictionary is empty.
(define (encoder-attach-dictionary! state dictionary quality)
  (if (zero? (bytes-length dictionary))
      #f
      (let ([prepared (BrotliEncoderPrepareDictionary BROTLI_SHARED_DICTIONARY_RAW
                                                      (bytes-length dictionary)
                                                      dictionary
                                                      quality
                                                      #f
                                                      #f
                                                      #f)])
        (unless prepared
          (error 'brotli "failed to prepare encoder dictionary"))
        (unless (not (zero? (BrotliEncoderAttachPreparedDictionary state prepared)))
          (BrotliEncoderDestroyPreparedDictionary prepared)
          (error 'brotli "failed to attach encoder dictionary"))
        prepared)))

;; Attach a dictionary to a decoder state.  Keeps a reference to the
;; dictionary bytes alive (caller's responsibility for streaming).
(define (decoder-attach-dictionary! state dictionary who)
  (when (> (bytes-length dictionary) 0)
    (unless (not (zero? (BrotliDecoderAttachDictionary state
                                                       BROTLI_SHARED_DICTIONARY_RAW
                                                       (bytes-length dictionary)
                                                       dictionary)))
      (error who "failed to attach decoder dictionary"))))

(define (brotli-compress! src
                          dst
                          [quality BROTLI_DEFAULT_QUALITY]
                          #:window [window BROTLI_DEFAULT_WINDOW]
                          #:mode [mode BROTLI_MODE_GENERIC]
                          #:lgblock [lgblock 0]
                          #:dictionary [dictionary #""])
  (define state (BrotliEncoderCreateInstance #f #f #f))
  (unless state
    (error 'brotli-compress! "failed to create encoder instance"))
  (define prepared-dict #f)
  (dynamic-wind
   void
   (lambda ()
     (unless (not (zero? (BrotliEncoderSetParameter state BROTLI_PARAM_QUALITY quality)))
       (error 'brotli-compress! "failed to set quality to ~a" quality))
     (unless (not (zero? (BrotliEncoderSetParameter state BROTLI_PARAM_LGWIN window)))
       (error 'brotli-compress! "failed to set window to ~a" window))
     (unless (not (zero? (BrotliEncoderSetParameter state BROTLI_PARAM_MODE mode)))
       (error 'brotli-compress! "failed to set mode to ~a" mode))
     (when (> lgblock 0)
       (unless (not (zero? (BrotliEncoderSetParameter state BROTLI_PARAM_LGBLOCK lgblock)))
         (error 'brotli-compress! "failed to set lgblock to ~a" lgblock)))
     (set! prepared-dict (encoder-attach-dictionary! state dictionary quality))
     ;; Compress the entire input with FINISH in one call, collecting output
     ;; into the pre-allocated dst buffer.
     (define sink (open-output-bytes))
     (encoder-compress-stream! state BROTLI_OPERATION_FINISH src sink)
     (define compressed (get-output-bytes sink))
     (define n (bytes-length compressed))
     (when (> n (bytes-length dst))
       (error 'brotli-compress! "output buffer too small"))
     (bytes-copy! dst 0 compressed 0 n)
     n)
   (lambda ()
     (when prepared-dict
       (BrotliEncoderDestroyPreparedDictionary prepared-dict))
     (BrotliEncoderDestroyInstance state))))

(define (brotli-decompress! src dst #:dictionary [dictionary #""])
  (define state (BrotliDecoderCreateInstance #f #f #f))
  (unless state
    (error 'brotli-decompress! "failed to create decoder instance"))
  (dynamic-wind void
                (lambda ()
                  (decoder-attach-dictionary! state dictionary 'brotli-decompress!)
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
                    (BrotliDecoderDecompressStream state
                                                   avail-in-ptr
                                                   next-in-ptr
                                                   avail-out-ptr
                                                   next-out-ptr
                                                   total-out-ptr))
                  (cond
                    [(= result BROTLI_DECODER_RESULT_SUCCESS) (ptr-ref total-out-ptr _size)]
                    [(= result BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT)
                     (error 'brotli-decompress! "output buffer too small")]
                    [(= result BROTLI_DECODER_RESULT_NEEDS_MORE_INPUT)
                     (error 'brotli-decompress! "input is incomplete")]
                    [else
                     (define code (BrotliDecoderGetErrorCode state))
                     (define msg (BrotliDecoderErrorString code))
                     (error 'brotli-decompress! "decompression failed: ~a" msg)]))
                (lambda () (BrotliDecoderDestroyInstance state))))

(define (brotli-compress src
                         [quality BROTLI_DEFAULT_QUALITY]
                         #:window [window BROTLI_DEFAULT_WINDOW]
                         #:mode [mode BROTLI_MODE_GENERIC]
                         #:lgblock [lgblock 0]
                         #:dictionary [dictionary #""])
  (define bound (BrotliEncoderMaxCompressedSize (bytes-length src)))
  (when (zero? bound)
    (error 'brotli-compress "input too large"))
  (define dst (make-bytes bound))
  (subbytes dst
            0
            (brotli-compress! src
                              dst
                              quality
                              #:window window
                              #:mode mode
                              #:lgblock lgblock
                              #:dictionary dictionary)))

(define (brotli-decompress src [max-decompressed-size #f] #:dictionary [dictionary #""])
  ;; Brotli streams do not embed the decompressed size, so we use
  ;; streaming decompression with a growing buffer.
  (define state (BrotliDecoderCreateInstance #f #f #f))
  (unless state
    (error 'brotli-decompress "failed to create decoder instance"))
  (dynamic-wind
   void
   (lambda ()
     (decoder-attach-dictionary! state dictionary 'brotli-decompress)
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
         (BrotliDecoderDecompressStream state
                                        avail-in-ptr
                                        next-in-ptr
                                        avail-out-ptr
                                        next-out-ptr
                                        total-out-ptr))
       (define written (- remaining (ptr-ref avail-out-ptr _size)))
       (bytes-copy! buf offset chunk-buf 0 written)
       (define new-offset (+ offset written))
       (cond
         [(= result BROTLI_DECODER_RESULT_SUCCESS) (subbytes buf 0 new-offset)]
         [(= result BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT)
          (define new-size (* (bytes-length buf) 2))
          (when (and max-decompressed-size (> new-size max-decompressed-size))
            (set! new-size max-decompressed-size))
          (when (<= new-size (bytes-length buf))
            (error 'brotli-decompress
                   "decompressed length exceeds max size (~a)"
                   max-decompressed-size))
          (define new-buf (make-bytes new-size))
          (bytes-copy! new-buf 0 buf 0 new-offset)
          (loop new-buf new-offset)]
         [(= result BROTLI_DECODER_RESULT_NEEDS_MORE_INPUT)
          (error 'brotli-decompress "input is incomplete or corrupted")]
         [else
          (define code (BrotliDecoderGetErrorCode state))
          (define msg (BrotliDecoderErrorString code))
          (error 'brotli-decompress "decompression failed: ~a" msg)])))
   (lambda () (BrotliDecoderDestroyInstance state))))

;; ---- Streaming Encoder Helpers ----

;; Drain all pending output from a streaming encoder into an output port.
(define (encoder-drain! state out)
  (let loop ()
    (when (not (zero? (BrotliEncoderHasMoreOutput state)))
      (define size-ptr (malloc _size 'atomic))
      (ptr-set! size-ptr _size 0) ; 0 = take as much as available
      (define data-ptr (BrotliEncoderTakeOutput state size-ptr))
      (define n (ptr-ref size-ptr _size))
      (when (> n 0)
        (define chunk (make-bytes n))
        (memcpy chunk data-ptr n)
        (write-bytes chunk out))
      (loop))))

;; Feed input to a streaming encoder with the given operation,
;; then drain all output.  Raises on encoder error.
(define (encoder-compress-stream! state op input-bstr out)
  (define avail-in-ptr (malloc _size 'atomic))
  (define next-in-ptr (malloc _pointer 'atomic))
  (define avail-out-ptr (malloc _size 'atomic))
  (define next-out-ptr (malloc _pointer 'atomic))
  (ptr-set! avail-in-ptr _size (bytes-length input-bstr))
  (ptr-set! next-in-ptr _pointer (if (zero? (bytes-length input-bstr)) #f input-bstr))
  ;; We set available_out to 0 and next_out to NULL, then use
  ;; BrotliEncoderTakeOutput to retrieve compressed data.
  ;; This avoids managing an intermediate output buffer.
  (ptr-set! avail-out-ptr _size 0)
  (ptr-set! next-out-ptr _pointer #f)
  (let loop ()
    (define ok
      (BrotliEncoderCompressStream state op avail-in-ptr next-in-ptr avail-out-ptr next-out-ptr #f))
    (when (zero? ok)
      (error 'brotli-encoder "compression stream error"))
    (encoder-drain! state out)
    ;; Keep calling until all input is consumed and no more output pending.
    (when (or (> (ptr-ref avail-in-ptr _size) 0) (not (zero? (BrotliEncoderHasMoreOutput state))))
      (loop))))

;; ---- Streaming Output Port ----

;; (open-brotli-output out [#:quality q] [#:window w] [#:mode m] [#:lgblock b] [#:close? c])
;;   -> output-port?
;;
;; Returns a new output port that brotli-compresses everything written to it
;; and forwards the compressed bytes to `out`.  Calling `flush-output` on the
;; returned port issues a BROTLI_OPERATION_FLUSH so the receiver can decode
;; all data written so far (essential for SSE streaming).  Closing the port
;; finalises the brotli stream with BROTLI_OPERATION_FINISH.
(define (open-brotli-output out
                            #:quality [quality 6]
                            #:window [window BROTLI_DEFAULT_WINDOW]
                            #:mode [mode BROTLI_MODE_GENERIC]
                            #:lgblock [lgblock 0]
                            #:dictionary [dictionary #""]
                            #:close? [close? #t]
                            #:name [name 'brotli-output])
  (define state (BrotliEncoderCreateInstance #f #f #f))
  (unless state
    (error 'open-brotli-output "failed to create encoder instance"))
  ;; Configure encoder parameters before any data is fed.
  (unless (not (zero? (BrotliEncoderSetParameter state BROTLI_PARAM_QUALITY quality)))
    (error 'open-brotli-output "failed to set quality to ~a" quality))
  (unless (not (zero? (BrotliEncoderSetParameter state BROTLI_PARAM_LGWIN window)))
    (error 'open-brotli-output "failed to set window to ~a" window))
  (unless (not (zero? (BrotliEncoderSetParameter state BROTLI_PARAM_MODE mode)))
    (error 'open-brotli-output "failed to set mode to ~a" mode))
  (when (> lgblock 0)
    (unless (not (zero? (BrotliEncoderSetParameter state BROTLI_PARAM_LGBLOCK lgblock)))
      (error 'open-brotli-output "failed to set lgblock to ~a" lgblock)))

  (define prepared-dict (encoder-attach-dictionary! state dictionary quality))

  (define closed? #f)

  ;; write-out : bytes nat nat bool bool -> nat or #f
  (define (write-out bstr start end non-block? breakable?)
    (when closed?
      (error 'brotli-output "port is closed"))
    (define chunk (subbytes bstr start end))
    (encoder-compress-stream! state BROTLI_OPERATION_PROCESS chunk out)
    (- end start))

  ;; close : -> void
  (define (close)
    (unless closed?
      (set! closed? #t)
      ;; Finalise the brotli stream.
      (encoder-compress-stream! state BROTLI_OPERATION_FINISH #"" out)
      (flush-output out)
      (when prepared-dict
        (BrotliEncoderDestroyPreparedDictionary prepared-dict))
      (BrotliEncoderDestroyInstance state)
      (when close?
        (close-output-port out))))

  ;; buffer-mode : called with 0 args to query, 1 arg to set.
  (define current-buffer-mode 'block)
  (define buffer-mode-proc
    (case-lambda
      [() current-buffer-mode]
      [(mode) (set! current-buffer-mode mode)]))

  (make-output-port name
                    out ; evt: ready when underlying port is ready
                    ;; write-out
                    (lambda (bstr start end non-block? breakable?)
                      (if (= start end)
                          ;; Zero-length write is a flush request.
                          (begin
                            (encoder-compress-stream! state BROTLI_OPERATION_FLUSH #"" out)
                            (flush-output out)
                            0)
                          (write-out bstr start end non-block? breakable?)))
                    ;; close
                    close
                    ;; write-out-special
                    #f
                    ;; get-write-evt
                    #f
                    ;; get-write-special-evt
                    #f
                    ;; get-location
                    #f
                    ;; count-lines!
                    void
                    ;; init-position
                    #f
                    ;; buffer-mode
                    buffer-mode-proc))

;; ---- Streaming Input Port ----

;; Drain any pending output from the decoder into the internal buffer.
(define (decoder-drain! state buf)
  (let loop ()
    (when (not (zero? (BrotliDecoderHasMoreOutput state)))
      (define size-ptr (malloc _size 'atomic))
      (ptr-set! size-ptr _size 0)
      (define data-ptr (BrotliDecoderTakeOutput state size-ptr))
      (define n (ptr-ref size-ptr _size))
      (when (> n 0)
        (define chunk (make-bytes n))
        (memcpy chunk data-ptr n)
        (write-bytes chunk buf))
      (loop))))

;; (open-brotli-input in [#:close? c] [#:name n]) -> input-port?
;;
;; Returns a new input port that decompresses Brotli-compressed data read
;; from `in`.  Closing the returned port destroys the decoder state.
;; If `close?` is #t (the default), the underlying port `in` is also closed.
(define (open-brotli-input in
                           #:dictionary [dictionary #""]
                           #:close? [close? #t]
                           #:name [name 'brotli-input])
  (define state (BrotliDecoderCreateInstance #f #f #f))
  (unless state
    (error 'open-brotli-input "failed to create decoder instance"))

  (decoder-attach-dictionary! state dictionary 'open-brotli-input)
  ;; Keep a reference to the dictionary bytes alive for the lifetime of the
  ;; decoder (the C library references the data directly).
  (define _dictionary-ref dictionary)

  ;; Internal buffer of decompressed bytes not yet returned to the caller.
  (define pending (open-output-bytes))
  (define pending-input (open-input-bytes #""))

  ;; Refresh the pending input port from the pending output buffer.
  (define (refresh-pending!)
    (define bs (get-output-bytes pending #t))
    (when (> (bytes-length bs) 0)
      (set! pending-input (open-input-bytes bs))))

  (define closed? #f)
  (define finished? #f)
  (define read-chunk-size 4096)

  ;; Feed compressed data from `in` through the decoder until we have
  ;; decompressed output or hit EOF / stream end.
  (define (fill-buffer!)
    (when (and (not finished?) (not closed?))
      (define compressed (read-bytes read-chunk-size in))
      (define eof? (eof-object? compressed))
      (define input-bstr (if eof? #"" compressed))
      (define avail-in-ptr (malloc _size 'atomic))
      (define next-in-ptr (malloc _pointer 'atomic))
      (define avail-out-ptr (malloc _size 'atomic))
      (define next-out-ptr (malloc _pointer 'atomic))
      (ptr-set! avail-in-ptr _size (bytes-length input-bstr))
      (ptr-set! next-in-ptr _pointer (if (zero? (bytes-length input-bstr)) #f input-bstr))
      ;; Use TakeOutput strategy (same as encoder): set avail_out=0, next_out=NULL.
      (ptr-set! avail-out-ptr _size 0)
      (ptr-set! next-out-ptr _pointer #f)
      (let loop ()
        (define result
          (BrotliDecoderDecompressStream state
                                         avail-in-ptr
                                         next-in-ptr
                                         avail-out-ptr
                                         next-out-ptr
                                         #f))
        (decoder-drain! state pending)
        (cond
          [(= result BROTLI_DECODER_RESULT_ERROR)
           (define code (BrotliDecoderGetErrorCode state))
           (define msg (BrotliDecoderErrorString code))
           (error 'brotli-input "decompression failed: ~a" msg)]
          [(= result BROTLI_DECODER_RESULT_SUCCESS) (set! finished? #t)]
          ;; Drain produced output and continue processing remaining input.
          [(= result BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT) (loop)]
          [(= result BROTLI_DECODER_RESULT_NEEDS_MORE_INPUT)
           ;; If we got EOF from the underlying port, the stream is truncated.
           (when eof?
             (error 'brotli-input "input is incomplete or corrupted"))]))))

  ;; read-in : bytes -> nat or eof
  (define (read-in bstr)
    ;; First, try to satisfy from already-decompressed pending bytes.
    (refresh-pending!)
    (define n (read-bytes-avail!* bstr pending-input))
    (cond
      [(and (number? n) (> n 0)) n]
      ;; Need more decompressed data.
      [finished? eof]
      [else
       (fill-buffer!)
       (refresh-pending!)
       (define m (read-bytes-avail!* bstr pending-input))
       (cond
         [(and (number? m) (> m 0)) m]
         [finished? eof]
         ;; Should not happen, but guard against infinite loops.
         [else eof])]))

  ;; close : -> void
  (define (do-close)
    (unless closed?
      (set! closed? #t)
      (BrotliDecoderDestroyInstance state)
      (when close?
        (close-input-port in))))

  (make-input-port name
                   ;; read-in
                   read-in
                   ;; peek (use #f for default based on read-in)
                   #f
                   ;; close
                   do-close))

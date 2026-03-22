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

(define-runtime-path libbrotlicommon.so '(so "libbrotlicommon"))
(define-runtime-path libbrotlienc.so '(so "libbrotlienc"))
(define-runtime-path libbrotlidec.so '(so "libbrotlidec"))

(void (ffi-lib libbrotlicommon.so))
(define-ffi-definer define-brotli-enc (ffi-lib libbrotlienc.so))
(define-ffi-definer define-brotli-dec (ffi-lib libbrotlidec.so))

(define BROTLI_MIN_QUALITY 0)
(define BROTLI_MAX_QUALITY 11)
(define BROTLI_DEFAULT_QUALITY 11)
(define BROTLI_MIN_WINDOW_BITS 10)
(define BROTLI_MAX_WINDOW_BITS 24)
(define BROTLI_DEFAULT_WINDOW 22)

(define BROTLI_MODE_GENERIC 0)
(define BROTLI_MODE_TEXT 1)
(define BROTLI_MODE_FONT 2)

(define BROTLI_OPERATION_PROCESS 0)
(define BROTLI_OPERATION_FLUSH 1)
(define BROTLI_OPERATION_FINISH 2)

(define BROTLI_PARAM_MODE 0)
(define BROTLI_PARAM_QUALITY 1)
(define BROTLI_PARAM_LGWIN 2)
(define BROTLI_PARAM_LGBLOCK 3)

(define BROTLI_SHARED_DICTIONARY_RAW 0)

(define BROTLI_DECODER_RESULT_ERROR 0)
(define BROTLI_DECODER_RESULT_SUCCESS 1)
(define BROTLI_DECODER_RESULT_NEEDS_MORE_INPUT 2)
(define BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT 3)

(define-brotli-enc BrotliEncoderMaxCompressedSize (_fun _size -> _size))
(define-brotli-enc BrotliEncoderCreateInstance (_fun _pointer _pointer _pointer -> _pointer))
(define-brotli-enc BrotliEncoderDestroyInstance (_fun _pointer -> _void))
(define-brotli-enc BrotliEncoderSetParameter (_fun _pointer _int _uint32 -> _int))
(define-brotli-enc BrotliEncoderCompressStream
                   (_fun _pointer _int _pointer _pointer _pointer _pointer _pointer -> _int))
(define-brotli-enc BrotliEncoderHasMoreOutput (_fun _pointer -> _int))
(define-brotli-enc BrotliEncoderTakeOutput (_fun _pointer _pointer -> _pointer))
(define-brotli-enc BrotliEncoderPrepareDictionary
                   (_fun _int _size _bytes _int _pointer _pointer _pointer -> _pointer))
(define-brotli-enc BrotliEncoderDestroyPreparedDictionary (_fun _pointer -> _void))
(define-brotli-enc BrotliEncoderAttachPreparedDictionary (_fun _pointer _pointer -> _int))

(define-brotli-dec BrotliDecoderCreateInstance (_fun _pointer _pointer _pointer -> _pointer))
(define-brotli-dec BrotliDecoderDestroyInstance (_fun _pointer -> _void))
(define-brotli-dec BrotliDecoderDecompressStream
                   (_fun _pointer _pointer _pointer _pointer _pointer _pointer -> _int))
(define-brotli-dec BrotliDecoderGetErrorCode (_fun _pointer -> _int))
(define-brotli-dec BrotliDecoderErrorString (_fun _int -> _string))
(define-brotli-dec BrotliDecoderHasMoreOutput (_fun _pointer -> _int))
(define-brotli-dec BrotliDecoderTakeOutput (_fun _pointer _pointer -> _pointer))
(define-brotli-dec BrotliDecoderAttachDictionary (_fun _pointer _int _size _bytes -> _int))

(define (encoder-attach-dictionary! state dictionary quality)
  (cond
    [(zero? (bytes-length dictionary)) #f]
    [else
     (define prepared
       (BrotliEncoderPrepareDictionary BROTLI_SHARED_DICTIONARY_RAW
                                       (bytes-length dictionary)
                                       dictionary
                                       quality
                                       #f
                                       #f
                                       #f))
     (unless prepared
       (error 'brotli "failed to prepare encoder dictionary"))
     (unless (not (zero? (BrotliEncoderAttachPreparedDictionary state prepared)))
       (BrotliEncoderDestroyPreparedDictionary prepared)
       (error 'brotli "failed to attach encoder dictionary"))
     prepared]))

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
     (let loop ([buf (make-bytes (max 256 (bytes-length src)))]
                [offset 0])
       (when (and max-decompressed-size (> (bytes-length buf) max-decompressed-size))
         (set! buf (subbytes buf 0 max-decompressed-size)))
       (define remaining (- (bytes-length buf) offset))
       (when (and max-decompressed-size (> offset max-decompressed-size))
         (error 'brotli-decompress "decompressed length exceeds max size (~a)" max-decompressed-size))
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

(define (encoder-drain! state out)
  (let loop ()
    (when (not (zero? (BrotliEncoderHasMoreOutput state)))
      (define size-ptr (malloc _size 'atomic))
      (ptr-set! size-ptr _size 0)
      (define data-ptr (BrotliEncoderTakeOutput state size-ptr))
      (define n (ptr-ref size-ptr _size))
      (when (> n 0)
        (define chunk (make-bytes n))
        (memcpy chunk data-ptr n)
        (write-bytes chunk out))
      (loop))))

(define (encoder-compress-stream! state op input-bstr out)
  (define avail-in-ptr (malloc _size 'atomic))
  (define next-in-ptr (malloc _pointer 'atomic))
  (define avail-out-ptr (malloc _size 'atomic))
  (define next-out-ptr (malloc _pointer 'atomic))
  (ptr-set! avail-in-ptr _size (bytes-length input-bstr))
  (ptr-set! next-in-ptr _pointer (if (zero? (bytes-length input-bstr)) #f input-bstr))
  (ptr-set! avail-out-ptr _size 0)
  (ptr-set! next-out-ptr _pointer #f)
  (let loop ()
    (define ok
      (BrotliEncoderCompressStream state op avail-in-ptr next-in-ptr avail-out-ptr next-out-ptr #f))
    (when (zero? ok)
      (error 'brotli-encoder "compression stream error"))
    (encoder-drain! state out)
    (when (or (> (ptr-ref avail-in-ptr _size) 0) (not (zero? (BrotliEncoderHasMoreOutput state))))
      (loop))))

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

  (define (write-out bstr start end non-block? breakable?) ;; review: ignore
    (when closed?
      (error 'brotli-output "port is closed"))
    (define chunk (subbytes bstr start end))
    (encoder-compress-stream! state BROTLI_OPERATION_PROCESS chunk out)
    (- end start))

  (define (close)
    (unless closed?
      (set! closed? #t)
      (encoder-compress-stream! state BROTLI_OPERATION_FINISH #"" out)
      (flush-output out)
      (when prepared-dict
        (BrotliEncoderDestroyPreparedDictionary prepared-dict))
      (BrotliEncoderDestroyInstance state)
      (when close?
        (close-output-port out))))

  (define current-buffer-mode 'block)
  (define buffer-mode-proc
    (case-lambda
      [() current-buffer-mode]
      [(new-mode) (set! current-buffer-mode new-mode)]))

  (make-output-port name
                    out
                    (lambda (bstr start end non-block? breakable?) ;; review: ignore
                      (cond
                        [(= start end)
                         (encoder-compress-stream! state BROTLI_OPERATION_FLUSH #"" out)
                         (flush-output out)
                         0]
                        [else (write-out bstr start end non-block? breakable?)]))
                    close
                    #f
                    #f
                    #f
                    #f
                    void
                    #f
                    buffer-mode-proc))

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

(define (open-brotli-input in
                           #:dictionary [dictionary #""]
                           #:close? [close? #t]
                           #:name [name 'brotli-input])
  (define state (BrotliDecoderCreateInstance #f #f #f))
  (unless state
    (error 'open-brotli-input "failed to create decoder instance"))

  (decoder-attach-dictionary! state dictionary 'open-brotli-input)
  (define _dictionary-ref dictionary)

  (define pending (open-output-bytes))
  (define pending-input (open-input-bytes #""))

  (define (refresh-pending!)
    (define bs (get-output-bytes pending #t))
    (when (> (bytes-length bs) 0)
      (set! pending-input (open-input-bytes bs))))

  (define closed? #f)
  (define finished? #f)
  (define read-chunk-size 4096)

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
          [(= result BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT) (loop)]
          [(= result BROTLI_DECODER_RESULT_NEEDS_MORE_INPUT)
           (when eof?
             (error 'brotli-input "input is incomplete or corrupted"))]
          [else (error 'brotli-input "unexpected decoder result: ~a" result)]))))

  (define (read-in bstr)
    (refresh-pending!)
    (define n (read-bytes-avail!* bstr pending-input))
    (cond
      [(and (number? n) (> n 0)) n]
      [finished? eof]
      [else
       (fill-buffer!)
       (refresh-pending!)
       (define m (read-bytes-avail!* bstr pending-input))
       (cond
         [(and (number? m) (> m 0)) m]
         [finished? eof]
         [else eof])]))

  (define (do-close)
    (unless closed?
      (set! closed? #t)
      (BrotliDecoderDestroyInstance state)
      (when close?
        (close-input-port in))))

  (make-input-port name read-in #f do-close))

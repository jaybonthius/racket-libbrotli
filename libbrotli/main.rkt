#lang racket/base

(require racket/contract
         "foreign.rkt")

(provide (contract-out
          ;; One-shot compression / decompression
          [brotli-compress!
           (->* (bytes? bytes?)
                (quality/c #:window window/c #:mode mode/c #:lgblock lgblock/c)
                exact-nonnegative-integer?)]
          [brotli-decompress! (-> bytes? bytes? exact-nonnegative-integer?)]
          [brotli-compress
           (->* (bytes?) (quality/c #:window window/c #:mode mode/c #:lgblock lgblock/c) bytes?)]
          [brotli-decompress (->* (bytes?) ((or/c #f exact-positive-integer?)) bytes?)]
          ;; Streaming output port
          [open-brotli-output
           (->* (output-port?)
                (#:quality quality/c
                           #:window window/c
                           #:mode mode/c
                           #:lgblock lgblock/c
                           #:close? boolean?
                           #:name symbol?)
                output-port?)]
          ;; Streaming input port
          [open-brotli-input (->* (input-port?) (#:close? boolean? #:name symbol?) input-port?)])

         ;; Constants (no contracts needed for plain values)
         quality/c
         window/c
         mode/c
         lgblock/c
         BROTLI_DEFAULT_QUALITY
         BROTLI_DEFAULT_WINDOW
         BROTLI_MIN_QUALITY
         BROTLI_MAX_QUALITY
         BROTLI_MIN_WINDOW_BITS
         BROTLI_MAX_WINDOW_BITS
         BROTLI_MODE_GENERIC
         BROTLI_MODE_TEXT
         BROTLI_MODE_FONT)

(define quality/c (integer-in 0 11))

(define window/c (integer-in 10 24))

(define mode/c (or/c (=/c 0) (=/c 1) (=/c 2)))

(define lgblock/c (or/c (=/c 0) (integer-in 16 24)))

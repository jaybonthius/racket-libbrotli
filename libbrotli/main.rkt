#lang racket/base

(require racket/contract/base
         "foreign.rkt")

(provide (contract-out
          [brotli-compress! ;; review: ignore
           (->* [bytes? bytes?]
                [quality/c #:window window/c #:mode mode/c #:lgblock lgblock/c #:dictionary bytes?]
                exact-nonnegative-integer?)]
          [brotli-decompress! ;; review: ignore
           (->* [bytes? bytes?] [#:dictionary bytes?] exact-nonnegative-integer?)]
          [brotli-compress ;; review: ignore
           (->* [bytes?]
                [quality/c #:window window/c #:mode mode/c #:lgblock lgblock/c #:dictionary bytes?]
                bytes?)]
          [brotli-decompress ;; review: ignore
           (->* [bytes?] [(or/c #f exact-positive-integer?) #:dictionary bytes?] bytes?)]
          [open-brotli-output ;; review: ignore
           (->* [output-port?]
                [#:quality quality/c
                 #:window window/c
                 #:mode mode/c
                 #:lgblock lgblock/c
                 #:dictionary bytes?
                 #:close? boolean?
                 #:name symbol?]
                output-port?)]
          [open-brotli-input ;; review: ignore
           (->* [input-port?] [#:dictionary bytes? #:close? boolean? #:name symbol?] input-port?)])
         quality/c
         window/c
         mode/c
         lgblock/c
         BROTLI_DEFAULT_QUALITY ;; review: ignore
         BROTLI_DEFAULT_WINDOW ;; review: ignore
         BROTLI_MIN_QUALITY ;; review: ignore
         BROTLI_MAX_QUALITY ;; review: ignore
         BROTLI_MIN_WINDOW_BITS ;; review: ignore
         BROTLI_MAX_WINDOW_BITS ;; review: ignore
         BROTLI_MODE_GENERIC ;; review: ignore
         BROTLI_MODE_TEXT ;; review: ignore
         BROTLI_MODE_FONT) ;; review: ignore

(define quality/c (integer-in 0 11))
(define window/c (integer-in 10 24))
(define mode/c (or/c (=/c 0) (=/c 1) (=/c 2)))
(define lgblock/c (or/c (=/c 0) (integer-in 16 24)))

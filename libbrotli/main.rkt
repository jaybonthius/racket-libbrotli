#lang racket/base

(require racket/contract
         "foreign.rkt")

(provide
 (contract-out
  [brotli-compress! (->* (bytes? bytes?) (quality/c) exact-nonnegative-integer?)]
  [brotli-decompress! (-> bytes? bytes? exact-nonnegative-integer?)]
  [brotli-compress (->* (bytes?) (quality/c) bytes?)]
  [brotli-decompress (->* (bytes?) ((or/c #f exact-positive-integer?)) bytes?)]))

(define quality/c
  (integer-in 0 11))

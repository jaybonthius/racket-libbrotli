#lang racket/base

(require rackunit
         libbrotli)

;; -- Round-trip: compress then decompress ---------------------------------

(test-case "round-trip with default quality"
  (define input #"Hello, Brotli! This is a test of the compression library.")
  (define compressed (brotli-compress input))
  (check-true (bytes? compressed))
  (check-true (< (bytes-length compressed) (bytes-length input)))
  (define decompressed (brotli-decompress compressed))
  (check-equal? decompressed input))

(test-case "round-trip with quality 0 (fastest)"
  (define input #"Fast compression at quality zero.")
  (define compressed (brotli-compress input 0))
  (check-equal? (brotli-decompress compressed) input))

(test-case "round-trip with quality 11 (best)"
  (define input #"Best compression at quality eleven.")
  (define compressed (brotli-compress input 11))
  (check-equal? (brotli-decompress compressed) input))

;; -- Empty input ----------------------------------------------------------

(test-case "round-trip with empty input"
  (define compressed (brotli-compress #""))
  (check-equal? (brotli-decompress compressed) #""))

;; -- In-place buffer variants ---------------------------------------------

(test-case "brotli-compress! and brotli-decompress!"
  (define input #"Testing the in-place buffer API.")
  (define max-compressed-size 256)
  (define dst (make-bytes max-compressed-size))
  (define compressed-len (brotli-compress! input dst))
  (check-true (> compressed-len 0))
  (check-true (<= compressed-len max-compressed-size))
  (define compressed (subbytes dst 0 compressed-len))

  (define out (make-bytes (bytes-length input)))
  (define decompressed-len (brotli-decompress! compressed out))
  (check-equal? decompressed-len (bytes-length input))
  (check-equal? (subbytes out 0 decompressed-len) input))

;; -- Larger payload -------------------------------------------------------

(test-case "round-trip with larger repetitive data"
  (define input (make-bytes 100000 (char->integer #\x)))
  (define compressed (brotli-compress input))
  ;; Repetitive data should compress very well.
  (check-true (< (bytes-length compressed) (bytes-length input)))
  (check-equal? (brotli-decompress compressed) input))

;; -- Error cases ----------------------------------------------------------

(test-case "brotli-decompress! with too-small output buffer"
  (define input #"Some data that needs space for decompression.")
  (define compressed (brotli-compress input))
  (define tiny-out (make-bytes 1))
  (check-exn exn:fail? (lambda () (brotli-decompress! compressed tiny-out))))

(test-case "brotli-decompress with invalid input"
  (check-exn exn:fail? (lambda () (brotli-decompress #"this is not valid brotli data"))))

(test-case "brotli-decompress with max-decompressed-size exceeded"
  (define input (make-bytes 1000 (char->integer #\a)))
  (define compressed (brotli-compress input))
  (check-exn exn:fail? (lambda () (brotli-decompress compressed 10))))

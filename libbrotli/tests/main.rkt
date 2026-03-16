#lang racket/base

(require rackunit
         racket/port
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

;; =========================================================================
;; Streaming output port tests
;; =========================================================================

(test-case "streaming: basic write and close round-trip"
  ;; Write data through a brotli output port, close it, then decompress.
  (define sink (open-output-bytes))
  (define bport (open-brotli-output sink #:quality 4 #:close? #f))
  (write-bytes #"Hello from the streaming encoder!" bport)
  (close-output-port bport)
  (define compressed (get-output-bytes sink))
  (check-true (> (bytes-length compressed) 0))
  (define decompressed (brotli-decompress compressed))
  (check-equal? decompressed #"Hello from the streaming encoder!"))

(test-case "streaming: multiple writes then close"
  (define sink (open-output-bytes))
  (define bport (open-brotli-output sink #:quality 4 #:close? #f))
  (write-bytes #"chunk one " bport)
  (write-bytes #"chunk two " bport)
  (write-bytes #"chunk three" bport)
  (close-output-port bport)
  (define compressed (get-output-bytes sink))
  (define decompressed (brotli-decompress compressed))
  (check-equal? decompressed #"chunk one chunk two chunk three"))

(test-case "streaming: flush produces decodable output mid-stream"
  ;; This is the key test for SSE: after a flush, the compressed bytes
  ;; produced so far must be decodable by the receiver.
  (define sink (open-output-bytes))
  (define bport (open-brotli-output sink #:quality 1 #:close? #f))
  ;; Write first event and flush.
  (write-bytes #"event: datastar-patch-elements\ndata: <div>hello</div>\n\n" bport)
  (flush-output bport)
  (define after-first-flush (get-output-bytes sink))
  (check-true (> (bytes-length after-first-flush) 0) "flush should produce output bytes")
  ;; Write second event and flush.
  (write-bytes #"event: datastar-patch-signals\ndata: signals {\"count\":1}\n\n" bport)
  (flush-output bport)
  ;; Close to finalize.
  (close-output-port bport)
  (define compressed (get-output-bytes sink))
  (define decompressed (brotli-decompress compressed))
  (check-equal? decompressed
                (bytes-append #"event: datastar-patch-elements\ndata: <div>hello</div>\n\n"
                              #"event: datastar-patch-signals\ndata: signals {\"count\":1}\n\n")))

(test-case "streaming: empty input"
  (define sink (open-output-bytes))
  (define bport (open-brotli-output sink #:quality 4 #:close? #f))
  (close-output-port bport)
  (define compressed (get-output-bytes sink))
  ;; Even with no data, finishing the stream produces a valid brotli frame.
  (define decompressed (brotli-decompress compressed))
  (check-equal? decompressed #""))

(test-case "streaming: large payload"
  (define input (make-bytes 100000 (char->integer #\z)))
  (define sink (open-output-bytes))
  (define bport (open-brotli-output sink #:quality 4 #:close? #f))
  (write-bytes input bport)
  (close-output-port bport)
  (define compressed (get-output-bytes sink))
  (check-true (< (bytes-length compressed) (bytes-length input))
              "large repetitive data should compress")
  (check-equal? (brotli-decompress compressed) input))

(test-case "streaming: different quality levels"
  (define input #"Testing different quality levels for the streaming encoder.")
  (for ([q (in-range 0 12)])
    (define sink (open-output-bytes))
    (define bport (open-brotli-output sink #:quality q #:close? #f))
    (write-bytes input bport)
    (close-output-port bport)
    (define compressed (get-output-bytes sink))
    (check-equal? (brotli-decompress compressed) input (format "quality ~a round-trip failed" q))))

(test-case "streaming: close? #t closes underlying port"
  (define sink (open-output-bytes))
  (define bport (open-brotli-output sink #:close? #t))
  (write-bytes #"data" bport)
  (close-output-port bport)
  (check-true (port-closed? sink) "underlying port should be closed"))

(test-case "streaming: write-string works through port"
  (define sink (open-output-bytes))
  (define bport (open-brotli-output sink #:quality 4 #:close? #f))
  (write-string "Hello, streaming brotli!" bport)
  (close-output-port bport)
  (define compressed (get-output-bytes sink))
  (check-equal? (brotli-decompress compressed) #"Hello, streaming brotli!"))

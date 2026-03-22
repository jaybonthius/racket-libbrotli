#lang racket/base

(require libbrotli
         racket/port
         rackunit)

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

(test-case "round-trip with empty input"
  (define compressed (brotli-compress #""))
  (check-equal? (brotli-decompress compressed) #""))

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

(test-case "round-trip with larger repetitive data"
  (define input (make-bytes 100000 (char->integer #\x)))
  (define compressed (brotli-compress input))
  (check-true (< (bytes-length compressed) (bytes-length input)))
  (check-equal? (brotli-decompress compressed) input))

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

(test-case "brotli-compress! with too-small output buffer"
  (define input (make-bytes 4096 (char->integer #\a)))
  (define tiny-dst (make-bytes 1))
  (check-exn exn:fail? (lambda () (brotli-compress! input tiny-dst))))

(test-case "round-trip with mode TEXT"
  (define input #"UTF-8 text content for text mode compression test.")
  (define compressed (brotli-compress input #:mode BROTLI_MODE_TEXT))
  (check-equal? (brotli-decompress compressed) input))

(test-case "round-trip with mode FONT"
  (define input #"Font data simulation for font mode compression test.")
  (define compressed (brotli-compress input #:mode BROTLI_MODE_FONT))
  (check-equal? (brotli-decompress compressed) input))

(test-case "round-trip with small window"
  (define input #"Testing compression with minimum window size.")
  (define compressed (brotli-compress input #:window 10))
  (check-equal? (brotli-decompress compressed) input))

(test-case "round-trip with large window"
  (define input #"Testing compression with maximum window size.")
  (define compressed (brotli-compress input #:window 24))
  (check-equal? (brotli-decompress compressed) input))

(test-case "round-trip with lgblock 16"
  (define input #"Testing compression with lgblock 16.")
  (define compressed (brotli-compress input #:lgblock 16))
  (check-equal? (brotli-decompress compressed) input))

(test-case "round-trip with lgblock 24"
  (define input #"Testing compression with lgblock 24.")
  (define compressed (brotli-compress input #:lgblock 24))
  (check-equal? (brotli-decompress compressed) input))

(test-case "round-trip with all parameters"
  (define input #"Testing compression with all parameters set explicitly.")
  (define compressed (brotli-compress input 5 #:mode BROTLI_MODE_TEXT #:window 18 #:lgblock 20))
  (check-equal? (brotli-decompress compressed) input))

(test-case "brotli-compress! with mode and window"
  (define input #"Buffer API with mode and window.")
  (define dst (make-bytes 256))
  (define n (brotli-compress! input dst #:mode BROTLI_MODE_TEXT #:window 16))
  (check-true (> n 0))
  (define compressed (subbytes dst 0 n))
  (check-equal? (brotli-decompress compressed) input))

(test-case "streaming: basic write and close round-trip"
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
  (define sink (open-output-bytes))
  (define bport (open-brotli-output sink #:quality 1 #:close? #f))
  (write-bytes #"event: datastar-patch-elements\ndata: <div>hello</div>\n\n" bport)
  (flush-output bport)
  (define after-first-flush (get-output-bytes sink))
  (check-true (> (bytes-length after-first-flush) 0) "flush should produce output bytes")
  (write-bytes #"event: datastar-patch-signals\ndata: signals {\"count\":1}\n\n" bport)
  (flush-output bport)
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

(test-case "streaming: close? #f leaves underlying port open"
  (define sink (open-output-bytes))
  (define bport (open-brotli-output sink #:close? #f))
  (write-bytes #"data" bport)
  (close-output-port bport)
  (check-false (port-closed? sink) "underlying port should remain open"))

(test-case "streaming: write-string works through port"
  (define sink (open-output-bytes))
  (define bport (open-brotli-output sink #:quality 4 #:close? #f))
  (write-string "Hello, streaming brotli!" bport)
  (close-output-port bport)
  (define compressed (get-output-bytes sink))
  (check-equal? (brotli-decompress compressed) #"Hello, streaming brotli!"))

(test-case "streaming: with lgblock parameter"
  (define sink (open-output-bytes))
  (define bport (open-brotli-output sink #:quality 4 #:lgblock 16 #:close? #f))
  (write-bytes #"Testing streaming with lgblock parameter." bport)
  (close-output-port bport)
  (define compressed (get-output-bytes sink))
  (check-equal? (brotli-decompress compressed) #"Testing streaming with lgblock parameter."))

(test-case "streaming: with mode TEXT"
  (define sink (open-output-bytes))
  (define bport (open-brotli-output sink #:quality 4 #:mode BROTLI_MODE_TEXT #:close? #f))
  (write-bytes #"Streaming UTF-8 text mode test." bport)
  (close-output-port bport)
  (define compressed (get-output-bytes sink))
  (check-equal? (brotli-decompress compressed) #"Streaming UTF-8 text mode test."))

(test-case "input-port: basic read round-trip"
  (define input #"Hello from the streaming decoder!")
  (define compressed (brotli-compress input))
  (define bport (open-brotli-input (open-input-bytes compressed) #:close? #f))
  (define decompressed (port->bytes bport))
  (close-input-port bport)
  (check-equal? decompressed input))

(test-case "input-port: read-string works through port"
  (define input #"Hello, streaming brotli input!")
  (define compressed (brotli-compress input))
  (define bport (open-brotli-input (open-input-bytes compressed) #:close? #f))
  (define decompressed (read-string 100 bport))
  (close-input-port bport)
  (check-equal? decompressed "Hello, streaming brotli input!"))

(test-case "input-port: incremental reads with small buffer"
  (define input #"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
  (define compressed (brotli-compress input))
  (define bport (open-brotli-input (open-input-bytes compressed) #:close? #f))
  (define result (open-output-bytes))
  (let loop ()
    (define chunk (read-bytes 4 bport))
    (unless (eof-object? chunk)
      (write-bytes chunk result)
      (loop)))
  (close-input-port bport)
  (check-equal? (get-output-bytes result) input))

(test-case "input-port: empty compressed input"
  (define compressed (brotli-compress #""))
  (define bport (open-brotli-input (open-input-bytes compressed) #:close? #f))
  (define decompressed (port->bytes bport))
  (close-input-port bport)
  (check-equal? decompressed #""))

(test-case "input-port: large payload"
  (define input (make-bytes 100000 (char->integer #\z)))
  (define compressed (brotli-compress input))
  (define bport (open-brotli-input (open-input-bytes compressed) #:close? #f))
  (define decompressed (port->bytes bport))
  (close-input-port bport)
  (check-equal? decompressed input))

(test-case "input-port: round-trip with open-brotli-output"
  (define input #"Symmetric streaming test: output port -> input port.")
  (define sink (open-output-bytes))
  (define out-port (open-brotli-output sink #:quality 4 #:close? #f))
  (write-bytes input out-port)
  (close-output-port out-port)
  (define compressed (get-output-bytes sink))
  (define in-port (open-brotli-input (open-input-bytes compressed) #:close? #f))
  (define decompressed (port->bytes in-port))
  (close-input-port in-port)
  (check-equal? decompressed input))

(test-case "input-port: close? #t closes underlying port"
  (define underlying (open-input-bytes (brotli-compress #"data")))
  (define bport (open-brotli-input underlying #:close? #t))
  (port->bytes bport)
  (close-input-port bport)
  (check-true (port-closed? underlying) "underlying port should be closed"))

(test-case "input-port: close? #f leaves underlying port open"
  (define underlying (open-input-bytes (brotli-compress #"data")))
  (define bport (open-brotli-input underlying #:close? #f))
  (port->bytes bport)
  (close-input-port bport)
  (check-false (port-closed? underlying) "underlying port should remain open"))

(test-case "input-port: invalid compressed data raises error"
  (define bport (open-brotli-input (open-input-bytes #"this is not valid brotli") #:close? #f))
  (check-exn exn:fail? (lambda () (port->bytes bport))))

(test-case "input-port: different compression qualities"
  (define input #"Testing input port with various quality levels.")
  (for ([q (in-range 0 12)])
    (define compressed (brotli-compress input q))
    (define bport (open-brotli-input (open-input-bytes compressed) #:close? #f))
    (define decompressed (port->bytes bport))
    (close-input-port bport)
    (check-equal? decompressed input (format "quality ~a round-trip via input port failed" q))))

(define test-dictionary #"The quick brown fox jumps over the lazy dog. HTTP/1.1 200 OK")

(test-case "dictionary: one-shot compress/decompress round-trip"
  (define input #"The quick brown fox jumps over the lazy dog.")
  (define compressed (brotli-compress input #:dictionary test-dictionary))
  (define decompressed (brotli-decompress compressed #:dictionary test-dictionary))
  (check-equal? decompressed input))

(test-case "dictionary: brotli-compress!/brotli-decompress! round-trip"
  (define input #"The quick brown fox jumps over the lazy dog.")
  (define dst (make-bytes 256))
  (define n (brotli-compress! input dst #:dictionary test-dictionary))
  (check-true (> n 0))
  (define compressed (subbytes dst 0 n))
  (define out (make-bytes (bytes-length input)))
  (define m (brotli-decompress! compressed out #:dictionary test-dictionary))
  (check-equal? (subbytes out 0 m) input))

(test-case "dictionary: improves compression ratio"
  (define input
    #"The quick brown fox jumps over the lazy dog. HTTP/1.1 200 OK Content-Type: text/html")
  (define without-dict (brotli-compress input))
  (define with-dict (brotli-compress input #:dictionary test-dictionary))
  (check-true (<= (bytes-length with-dict) (bytes-length without-dict))
              "dictionary should not make compression worse"))

(test-case "dictionary: wrong dictionary fails to decompress correctly"
  (define input #"The quick brown fox jumps.")
  (define compressed (brotli-compress input #:dictionary test-dictionary))
  (define wrong-dict #"completely different dictionary content here")
  (check-exn exn:fail?
             (lambda ()
               (define result (brotli-decompress compressed #:dictionary wrong-dict))
               (unless (equal? result input)
                 (error "wrong output")))))

(test-case "dictionary: empty dictionary is no-op"
  (define input #"Hello, Brotli!")
  (define without (brotli-compress input))
  (define with-empty (brotli-compress input #:dictionary #""))
  (check-equal? without with-empty))

(test-case "dictionary: streaming output port round-trip"
  (define input #"The quick brown fox jumps over the lazy dog.")
  (define sink (open-output-bytes))
  (define bport (open-brotli-output sink #:quality 4 #:dictionary test-dictionary #:close? #f))
  (write-bytes input bport)
  (close-output-port bport)
  (define compressed (get-output-bytes sink))
  (define decompressed (brotli-decompress compressed #:dictionary test-dictionary))
  (check-equal? decompressed input))

(test-case "dictionary: streaming input port round-trip"
  (define input #"The quick brown fox jumps over the lazy dog.")
  (define compressed (brotli-compress input #:dictionary test-dictionary))
  (define bport
    (open-brotli-input (open-input-bytes compressed) #:dictionary test-dictionary #:close? #f))
  (define decompressed (port->bytes bport))
  (close-input-port bport)
  (check-equal? decompressed input))

(test-case "dictionary: streaming output -> streaming input round-trip"
  (define input #"The quick brown fox jumps over the lazy dog. HTTP/1.1 200 OK")
  (define sink (open-output-bytes))
  (define out-port (open-brotli-output sink #:quality 4 #:dictionary test-dictionary #:close? #f))
  (write-bytes input out-port)
  (close-output-port out-port)
  (define compressed (get-output-bytes sink))
  (define in-port
    (open-brotli-input (open-input-bytes compressed) #:dictionary test-dictionary #:close? #f))
  (define decompressed (port->bytes in-port))
  (close-input-port in-port)
  (check-equal? decompressed input))

(test-case "contract: invalid quality rejected"
  (check-exn exn:fail? (lambda () (brotli-compress #"data" 15)))
  (check-exn exn:fail? (lambda () (brotli-compress #"data" -1))))

(test-case "contract: invalid window rejected"
  (check-exn exn:fail? (lambda () (brotli-compress #"data" #:window 5)))
  (check-exn exn:fail? (lambda () (brotli-compress #"data" #:window 25))))

(test-case "contract: invalid mode rejected"
  (check-exn exn:fail? (lambda () (brotli-compress #"data" #:mode 3)))
  (check-exn exn:fail? (lambda () (brotli-compress #"data" #:mode -1))))

(test-case "contract: invalid lgblock rejected"
  (check-exn exn:fail? (lambda () (brotli-compress #"data" #:lgblock 7)))
  (check-exn exn:fail? (lambda () (brotli-compress #"data" #:lgblock 15)))
  (check-exn exn:fail? (lambda () (brotli-compress #"data" #:lgblock 25))))

(test-case "brotli-compress! with lgblock and dictionary"
  (define input #"The quick brown fox jumps over the lazy dog.")
  (define dst (make-bytes 256))
  (define n (brotli-compress! input dst #:lgblock 16 #:dictionary test-dictionary))
  (check-true (> n 0))
  (define compressed (subbytes dst 0 n))
  (define decompressed (brotli-decompress compressed #:dictionary test-dictionary))
  (check-equal? decompressed input))

(test-case "streaming output: dictionary + mode + window + lgblock combined"
  (define input #"The quick brown fox jumps over the lazy dog. HTTP/1.1 200 OK")
  (define sink (open-output-bytes))
  (define bport
    (open-brotli-output sink
                        #:quality 5
                        #:mode BROTLI_MODE_TEXT
                        #:window 18
                        #:lgblock 16
                        #:dictionary test-dictionary
                        #:close? #f))
  (write-bytes input bport)
  (close-output-port bport)
  (define compressed (get-output-bytes sink))
  (define decompressed (brotli-decompress compressed #:dictionary test-dictionary))
  (check-equal? decompressed input))

(test-case "dictionary: strictly improves ratio on overlapping data"
  (define input
    (apply bytes-append
           (for/list ([_ (in-range 20)])
             #"The quick brown fox jumps over the lazy dog. HTTP/1.1 200 OK ")))
  (define without-dict (brotli-compress input))
  (define with-dict (brotli-compress input #:dictionary test-dictionary))
  (check-true (< (bytes-length with-dict) (bytes-length without-dict))
              "dictionary should strictly improve compression on highly overlapping data"))

(test-case "dictionary: streaming input port with wrong dictionary"
  (define input #"The quick brown fox jumps over the lazy dog.")
  (define compressed (brotli-compress input #:dictionary test-dictionary))
  (define wrong-dict #"completely different dictionary content here")
  (check-exn
   exn:fail?
   (lambda ()
     (define bport
       (open-brotli-input (open-input-bytes compressed) #:dictionary wrong-dict #:close? #f))
     (define result (port->bytes bport))
     (close-input-port bport)
     (unless (equal? result input)
       (error "wrong output")))))

(test-case "round-trip with non-uniform large payload"
  (define size 100000)
  (define buf (make-bytes size))
  (for ([i (in-range size)])
    (bytes-set! buf i (modulo (* i 7919) 256)))
  (define compressed (brotli-compress buf))
  (check-equal? (brotli-decompress compressed) buf))

(test-case "streaming round-trip with non-uniform large payload"
  (define size 100000)
  (define buf (make-bytes size))
  (for ([i (in-range size)])
    (bytes-set! buf i (modulo (* i 7919) 256)))
  (define sink (open-output-bytes))
  (define out-port (open-brotli-output sink #:quality 4 #:close? #f))
  (write-bytes buf out-port)
  (close-output-port out-port)
  (define compressed (get-output-bytes sink))
  (define in-port (open-brotli-input (open-input-bytes compressed) #:close? #f))
  (define decompressed (port->bytes in-port))
  (close-input-port in-port)
  (check-equal? decompressed buf))

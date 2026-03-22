#lang racket/base

(require libbrotli
         racket/contract/base
         racket/string
         web-server/http)

(provide (contract-out [wrap-brotli-compress
                        (->* [(-> request? response?)]
                             [#:quality quality/c #:window window/c #:mode mode/c]
                             (-> request? response?))]))

(define (accepts-encoding? req encoding)
  (define enc-str (symbol->string encoding))
  (define accept-header
    (for/or ([h (in-list (request-headers/raw req))])
      (and (equal? (string-downcase (bytes->string/utf-8 (header-field h))) "accept-encoding")
           (header-value h))))
  (and accept-header
       (for/or ([part (in-list (regexp-split #rx"," (bytes->string/utf-8 accept-header)))])
         (string-ci=? (string-trim (car (string-split part ";"))) enc-str))))

(define (wrap-brotli-compress handler
                              #:quality [quality 5]
                              #:window [window 22]
                              #:mode [mode BROTLI_MODE_TEXT])
  (lambda (req)
    (define resp (handler req))
    (cond
      [(accepts-encoding? req 'br)
       (define original-output (response-output resp))
       (struct-copy
        response
        resp
        [headers
         (list* (make-header #"Content-Encoding" #"br")
                (make-header #"Vary" #"Accept-Encoding")
                (response-headers resp))]
        [output
         (lambda (raw-out)
           (define out
             (open-brotli-output raw-out #:quality quality #:window window #:mode mode #:close? #f))
           (original-output out)
           (close-output-port out))])]
      [else resp])))

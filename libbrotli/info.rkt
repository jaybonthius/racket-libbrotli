#lang info
#|review: ignore|#

(define license 'MIT)
(define collection "libbrotli")
(define version "0.1")
(define deps
  '("base" ["libbrotli-aarch64-linux" #:platform #rx"aarch64-linux"]
           ["libbrotli-aarch64-macosx" #:platform #rx"aarch64-macosx"]
           ["libbrotli-x86_64-linux" #:platform #rx"x86_64-linux"]
           ["libbrotli-x86_64-macosx" #:platform #rx"x86_64-macosx"]
           ["libbrotli-i386-win32" #:platform #rx"win32.i386"]
           ["libbrotli-x86_64-win32" #:platform #rx"win32.x86_64"]))
(define scribblings '(("scribblings/libbrotli.scrbl")))
(define build-deps '("rackunit-lib" "scribble-lib" "racket-doc"))

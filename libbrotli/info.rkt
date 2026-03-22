#lang info

(define license 'MIT)
(define collection "libbrotli")
(define version "1.0")
(define deps
  '("base" "web-server-lib"
           ["libbrotli-aarch64-linux" #:platform #rx"aarch64-linux"]
           ["libbrotli-aarch64-macosx" #:platform #rx"aarch64-macosx"]
           ["libbrotli-x86_64-linux" #:platform #rx"x86_64-linux"]
           ["libbrotli-x86_64-macosx" #:platform #rx"x86_64-macosx"]
           ["libbrotli-i386-win32" #:platform #rx"win32.i386"]
           ["libbrotli-x86_64-win32" #:platform #rx"win32.x86_64"]))
(define build-deps '("scribble-lib" "racket-doc" "rackunit-lib" "web-server-doc"))

(define scribblings '(("scribblings/libbrotli.scrbl")))

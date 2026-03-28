#lang scribble/doc

@(require scribble/manual
          (for-label libbrotli
                     racket/base
                     racket/contract))

@title{libbrotli}

@author[(author+email "Jay Bonthius" "jay@jmbmail.com")]

@defmodule[libbrotli]

Racket bindings to Google's @link["https://github.com/google/brotli"]{Brotli}
compression library.

@section{One-Shot Compression}

@defproc[(brotli-compress [src bytes?]
                          [quality quality/c BROTLI_DEFAULT_QUALITY]
                          [#:window window window/c BROTLI_DEFAULT_WINDOW]
                          [#:mode mode mode/c BROTLI_MODE_GENERIC]
                          [#:lgblock lgblock lgblock/c 0]
                          [#:dictionary dictionary bytes? #""])
         bytes?]{
Compresses @racket[src] and returns the compressed bytes.

@racketblock[
(require libbrotli)

(define compressed (brotli-compress #"hello world"))
(brotli-decompress compressed) ; => #"hello world"
]
}

@defproc[(brotli-decompress [src bytes?]
                            [max-decompressed-size (or/c #f exact-positive-integer?) #f]
                            [#:dictionary dictionary bytes? #""])
         bytes?]{
Decompresses @racket[src] and returns the original bytes. If
@racket[max-decompressed-size] is not @racket[#f], limits the output size to
prevent decompression bombs.
}

@section{Buffer Compression}

@defproc[(brotli-compress! [src bytes?]
                           [dst bytes?]
                           [quality quality/c BROTLI_DEFAULT_QUALITY]
                           [#:window window window/c BROTLI_DEFAULT_WINDOW]
                           [#:mode mode mode/c BROTLI_MODE_GENERIC]
                           [#:lgblock lgblock lgblock/c 0]
                           [#:dictionary dictionary bytes? #""])
         exact-nonnegative-integer?]{
Compresses @racket[src] into the pre-allocated buffer @racket[dst]. Returns the
number of bytes written. Raises an error if @racket[dst] is too small.
}

@defproc[(brotli-decompress! [src bytes?]
                             [dst bytes?]
                             [#:dictionary dictionary bytes? #""])
         exact-nonnegative-integer?]{
Decompresses @racket[src] into the pre-allocated buffer @racket[dst]. Returns the
number of bytes written. Raises an error if @racket[dst] is too small.
}

@section{Streaming Ports}

@defproc[(open-brotli-output [out output-port?]
                             [#:quality quality quality/c 6]
                             [#:window window window/c BROTLI_DEFAULT_WINDOW]
                             [#:mode mode mode/c BROTLI_MODE_GENERIC]
                             [#:lgblock lgblock lgblock/c 0]
                             [#:dictionary dictionary bytes? #""]
                             [#:close? close? boolean? #t]
                             [#:name name symbol? 'brotli-output])
         output-port?]{
Returns an output port that compresses data written to it and forwards the
compressed bytes to @racket[out]. Closing the returned port flushes the
remaining compressed data. If @racket[close?] is @racket[#t], closing also
closes @racket[out].

Note: the default quality for streaming is 6 (not 11), which is a better
tradeoff for real-time use.

@racketblock[
(require libbrotli)

(define out (open-output-bytes))
(define brotli-out (open-brotli-output out))
(write-bytes #"hello world" brotli-out)
(close-output-port brotli-out)
(brotli-decompress (get-output-bytes out)) ; => #"hello world"
]
}

@defproc[(open-brotli-input [in input-port?]
                            [#:dictionary dictionary bytes? #""]
                            [#:close? close? boolean? #t]
                            [#:name name symbol? 'brotli-input])
         input-port?]{
Returns an input port that decompresses Brotli-encoded data read from
@racket[in]. If @racket[close?] is @racket[#t], closing the returned port also
closes @racket[in].
}

@section{Constants}

@defthing[BROTLI_DEFAULT_QUALITY exact-nonnegative-integer? #:value 11]{
Default compression quality for one-shot functions.
}

@defthing[BROTLI_MIN_QUALITY exact-nonnegative-integer? #:value 0]{
Minimum compression quality (fastest, lowest ratio).
}

@defthing[BROTLI_MAX_QUALITY exact-nonnegative-integer? #:value 11]{
Maximum compression quality (slowest, highest ratio).
}

@defthing[BROTLI_DEFAULT_WINDOW exact-nonnegative-integer? #:value 22]{
Default sliding window size in bits.
}

@defthing[BROTLI_MIN_WINDOW_BITS exact-nonnegative-integer? #:value 10]{
Minimum window size (1 KB).
}

@defthing[BROTLI_MAX_WINDOW_BITS exact-nonnegative-integer? #:value 24]{
Maximum window size (16 MB).
}

@defthing[BROTLI_MODE_GENERIC exact-nonnegative-integer? #:value 0]{
Default compression mode. Works for any input.
}

@defthing[BROTLI_MODE_TEXT exact-nonnegative-integer? #:value 1]{
Compression mode optimized for UTF-8 text.
}

@defthing[BROTLI_MODE_FONT exact-nonnegative-integer? #:value 2]{
Compression mode optimized for WOFF 2.0 fonts.
}

@section{Contracts}

@defthing[quality/c flat-contract?]{
Integer in the range @racket[0] to @racket[11].
}

@defthing[window/c flat-contract?]{
Integer in the range @racket[10] to @racket[24].
}

@defthing[mode/c flat-contract?]{
One of @racket[0], @racket[1], or @racket[2] (corresponding to
@racket[BROTLI_MODE_GENERIC], @racket[BROTLI_MODE_TEXT], and
@racket[BROTLI_MODE_FONT]).
}

@defthing[lgblock/c flat-contract?]{
Either @racket[0] (automatic) or an integer in the range @racket[16] to
@racket[24].
}

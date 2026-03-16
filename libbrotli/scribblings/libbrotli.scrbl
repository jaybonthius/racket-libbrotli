#lang scribble/doc

@(require scribble/manual
          (for-label libbrotli
                     racket/base
                     racket/contract))

@title{libbrotli: Brotli Compression for Racket}

@author[(author+email "Jay Bonthius" "jay@jmbmail.com")]

@defmodule[libbrotli]

Racket bindings for @link["https://github.com/google/brotli"]{Google's Brotli}
compression library. Provides one-shot compression/decompression of byte strings
and a streaming output port for incremental compression.

@section{One-Shot Compression}

@defproc[(brotli-compress [src bytes?]
                          [quality quality/c BROTLI_DEFAULT_QUALITY]) bytes?]{
Compresses @racket[src] and returns a fresh byte string containing the compressed
output. The optional @racket[quality] controls the compression level.
}

@defproc[(brotli-compress! [src bytes?]
                           [dst bytes?]
                           [quality quality/c BROTLI_DEFAULT_QUALITY]) exact-nonnegative-integer?]{
Compresses @racket[src] into the pre-allocated buffer @racket[dst]. Returns the
number of bytes written to @racket[dst]. Raises @racket[exn:fail?] if compression
fails (e.g., @racket[dst] is too small).
}

@section{One-Shot Decompression}

@defproc[(brotli-decompress [src bytes?]
                            [max-decompressed-size (or/c #f exact-positive-integer?) #f]) bytes?]{
Decompresses @racket[src] and returns a fresh byte string. When
@racket[max-decompressed-size] is not @racket[#f], the decompressed output is
bounded to that many bytes; an @racket[exn:fail?] is raised if the limit is
exceeded. This guards against decompression bombs.
}

@defproc[(brotli-decompress! [src bytes?]
                             [dst bytes?]) exact-nonnegative-integer?]{
Decompresses @racket[src] into the pre-allocated buffer @racket[dst]. Returns the
number of bytes written. Raises @racket[exn:fail?] if @racket[dst] is too small or
the input is invalid.
}

@section{Streaming Output Port}

@defproc[(open-brotli-output [out output-port?]
                             [#:quality quality quality/c 6]
                             [#:window window window/c BROTLI_DEFAULT_WINDOW]
                             [#:mode mode mode/c BROTLI_MODE_GENERIC]
                             [#:close? close? boolean? #t]
                             [#:name name symbol? 'brotli-output]) output-port?]{
Returns a new output port that compresses everything written to it with Brotli and
forwards the compressed bytes to @racket[out].

Calling @racket[flush-output] on the returned port issues a Brotli
@tt{FLUSH} operation, ensuring the receiver can decode all data written so far.
This is essential for streaming protocols like SSE.

Closing the returned port finalises the Brotli stream. If @racket[close?] is
@racket[#t] (the default), the underlying port @racket[out] is also closed;
otherwise it is left open.
}

@section{Contracts}

@defthing[quality/c flat-contract?]{
Equivalent to @racket[(integer-in 0 11)]. Accepts compression quality levels from
@racket[0] (fastest) to @racket[11] (smallest output).
}

@defthing[window/c flat-contract?]{
Equivalent to @racket[(integer-in 10 24)]. Accepts sliding-window sizes (as a
power of two) from @racket[10] to @racket[24]. Larger values may improve
compression at the cost of memory.
}

@defthing[mode/c flat-contract?]{
Accepts one of @racket[BROTLI_MODE_GENERIC] (@racket[0]),
@racket[BROTLI_MODE_TEXT] (@racket[1]), or @racket[BROTLI_MODE_FONT] (@racket[2]).
}

@section{Constants}

@subsection{Defaults}

@defthing[BROTLI_DEFAULT_QUALITY exact-nonnegative-integer? #:value 11]{
The default compression quality used by @racket[brotli-compress] and
@racket[brotli-compress!].
}

@defthing[BROTLI_DEFAULT_WINDOW exact-nonnegative-integer? #:value 22]{
The default sliding-window size used by @racket[open-brotli-output].
}

@subsection{Quality Range}

@defthing[BROTLI_MIN_QUALITY exact-nonnegative-integer? #:value 0]{
Minimum compression quality (fastest).
}

@defthing[BROTLI_MAX_QUALITY exact-nonnegative-integer? #:value 11]{
Maximum compression quality (smallest output).
}

@subsection{Window Range}

@defthing[BROTLI_MIN_WINDOW_BITS exact-nonnegative-integer? #:value 10]{
Minimum sliding-window size.
}

@defthing[BROTLI_MAX_WINDOW_BITS exact-nonnegative-integer? #:value 24]{
Maximum sliding-window size.
}

@subsection{Compression Modes}

@defthing[BROTLI_MODE_GENERIC mode/c #:value 0]{
Generic mode. No assumptions about content type.
}

@defthing[BROTLI_MODE_TEXT mode/c #:value 1]{
Text mode. Optimized for UTF-8 input.
}

@defthing[BROTLI_MODE_FONT mode/c #:value 2]{
Font mode. Optimized for WOFF 2.0 fonts.
}

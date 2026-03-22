# racket-libbrotli [![Build](https://github.com/jaybonthius/racket-libbrotli/actions/workflows/push.yml/badge.svg?branch=main)](https://github.com/jaybonthius/racket-libbrotli/actions/workflows/push.yml)

This package distributes [libbrotli] as a Racket package for Linux,
macOS, and Windows.

Each platform package ships three shared libraries:
`libbrotlicommon`, `libbrotlienc`, and `libbrotlidec`.

The dynamic libraries are built on the following systems:

| Package                  | OS/Version  | Compatibility                           |
|--------------------------|-------------|-----------------------------------------|
| libbrotli-aarch64-linux  | Debian 10   | Ubuntu 18.04 and up, Debian 10 and up   |
| libbrotli-x86_64-linux   | Debian 10   | Ubuntu 18.04 and up, Debian 10 and up   |
| libbrotli-aarch64-macosx | macOS 15    | macOS 14 (Sonoma) and up                |
| libbrotli-x86_64-macosx  | macOS 15    | macOS 15 (Sequoia) and up               |
| libbrotli-i386-win32     | Windows 11  | Windows 11 and up                       |
| libbrotli-x86_64-win32   | Windows 11  | Windows 11 and up                       |


[libbrotli]: https://github.com/google/brotli

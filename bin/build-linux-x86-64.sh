#!/usr/bin/env bash

set -euxo pipefail

git submodule update --init
export PREFIX="$(pwd)/artifacts/linux-x86-64"
docker run --rm \
       -e PREFIX="$PREFIX" \
       -v "$(pwd)":"$(pwd)" \
       -w "$(pwd)" \
       debian:10.0 \
       bash -c 'apt update && apt install -y build-essential cmake && mkdir -p brotli/out && cd brotli/out && cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" -DBUILD_SHARED_LIBS=ON .. && cmake --build . --config Release --target install && strip "$PREFIX"/lib/libbrotlicommon.so.1.1.0 "$PREFIX"/lib/libbrotlienc.so.1.1.0 "$PREFIX"/lib/libbrotlidec.so.1.1.0'

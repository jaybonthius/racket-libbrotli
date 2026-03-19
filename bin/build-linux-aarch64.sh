#!/usr/bin/env bash

set -euxo pipefail

git submodule update --init
export PREFIX="$(pwd)/artifacts/linux-aarch64"
docker run --rm \
       -e PREFIX="$PREFIX" \
       -v "$(pwd)":"$(pwd)" \
       -w "$(pwd)" \
       debian:10 \
       bash -c 'sed -i "s|deb.debian.org|archive.debian.org|g" /etc/apt/sources.list && sed -i "/buster-updates/d" /etc/apt/sources.list && apt update && apt install -y build-essential cmake && mkdir -p brotli/out && cd brotli/out && cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" -DBUILD_SHARED_LIBS=ON .. && cmake --build . --config Release --target install && find "$PREFIX"/lib -name "libbrotli*.so.*" -not -type l -exec strip {} +'

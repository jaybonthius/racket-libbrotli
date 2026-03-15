#!/usr/bin/env bash

set -euxo pipefail

git submodule update --init

export PREFIX="$(pwd)/artifacts/macos-aarch64"
mkdir -p brotli/out
pushd brotli/out

cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" -DBUILD_SHARED_LIBS=ON ..
cmake --build . --config Release --target install
popd

#!/usr/bin/env bash

set -euo pipefail

log() {
    printf "[%s] %s\n" "$(date)" "$@"
}

log "Ensuring artifact folders are present..."
test -e artifacts/linux-aarch64 || exit 2
test -e artifacts/linux-x86-64 || exit 2
test -e artifacts/macos-aarch64 || exit 2
test -e artifacts/macos-x86-64 || exit 2
test -e artifacts/win32-i386 || exit 2
test -e artifacts/win32-x86-64 || exit 2

log "Copying artifacts into their respective packages..."
for lib in libbrotlicommon libbrotlienc libbrotlidec; do
    cp "artifacts/linux-aarch64/lib/${lib}.so.1.1.0" "libbrotli-aarch64-linux/${lib}.so"
    cp "artifacts/linux-x86-64/lib/${lib}.so.1.1.0" "libbrotli-x86_64-linux/${lib}.so"
    cp "artifacts/macos-aarch64/lib/${lib}.1.1.0.dylib" "libbrotli-aarch64-macosx/${lib}.dylib"
    cp "artifacts/macos-x86-64/lib/${lib}.1.1.0.dylib" "libbrotli-x86_64-macosx/${lib}.dylib"
    cp "artifacts/win32-i386/lib/${lib}.dll" "libbrotli-i386-win32/${lib}.dll"
    cp "artifacts/win32-x86-64/lib/${lib}.dll" "libbrotli-x86_64-win32/${lib}.dll"
done

log "Decrypting deploy key..."
gpg -q \
    --batch \
    --yes \
    --decrypt \
    --passphrase="$DEPLOY_KEY_PASSPHRASE" \
    -o deploy-key \
    bin/deploy-key.gpg
chmod 0600 deploy-key
trap "rm -f deploy-key" EXIT

log "Building packages..."
for package in "libbrotli-aarch64-linux" "libbrotli-aarch64-macosx" "libbrotli-x86_64-linux" "libbrotli-x86_64-macosx" "libbrotli-i386-win32" "libbrotli-x86_64-win32"; do
    log "Building '$package'..."
    pushd "$package"

    version=$(grep version info.rkt | cut -d'"' -f2)
    filename="$package-$version.tar.gz"
    mkdir -p dist
    tar -cvzf "dist/$filename" LICENSE info.rkt libbrotli*
    sha1sum "dist/$filename" | cut -d ' ' -f 1 | tr -d '\n' > "dist/$filename.CHECKSUM"
    scp -o StrictHostKeyChecking=no \
        -i ../deploy-key \
        -P "$DEPLOY_PORT" \
        "dist/$filename" \
        "dist/$filename.CHECKSUM" \
        "$DEPLOY_USER@$DEPLOY_HOST":~/www/

    popd
done

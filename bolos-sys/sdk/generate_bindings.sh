#!/usr/bin/env bash

SCRIPT_DIR=$(dirname "$0")

: "${TMP_HEADERS_PATH:=/tmp/bolos/arm-none-eabi}"
: "${DOCKER_IMAGE:=zondax/builder-bolos:latest}"
: "${GCC_BOLOS_PATH:=gcc-arm-none-eabi-10-2020-q4-major}"

: "${BOLOS_SDK_S_PATH:=$SCRIPT_DIR/nanos-secure-sdk}"
: "${BOLOS_SDK_S_GIT:=https://github.com/LedgerHQ/nanos-secure-sdk}"
: "${BOLOS_SDK_S_GIT_HASH:=1a20ae6b83329c6c0107eec0a3002a199355abbb}"
: "${BOLOS_SDK_X_PATH:=$SCRIPT_DIR/nanox-secure-sdk}"
: "${BOLOS_SDK_X_GIT:=https://github.com/LedgerHQ/nanox-secure-sdk}"
: "${BOLOS_SDK_X_GIT_HASH:=a79eaf92aef434a5e63caca6b238fd00db523c8f}"

TMP_HEADERS=$(dirname $TMP_HEADERS_PATH)

echo "Checkout X SDK & update in $BOLOS_SDK_X_PATH from $BOLOS_SDK_X_GIT $BOLOS_SDK_X_GIT_HASH"
git submodule add "$BOLOS_SDK_X_GIT" "$BOLOS_SDK_X_PATH" || true
git submodule update --init "$BOLOS_SDK_X_PATH"
pushd "$BOLOS_SDK_X_PATH" || exit
git checkout $BOLOS_SDK_X_GIT_HASH
popd || exit

echo "Checkout S SDK & update in $BOLOS_SDK_S_PATH from $BOLOS_SDK_S_GIT $BOLOS_SDK_S_GIT_HASH"
git submodule add -b "$BOLOS_SDK_S_GIT_HASH" "$BOLOS_SDK_S_GIT" "$BOLOS_SDK_S_PATH" || true
git submodule update --init "$BOLOS_SDK_S_PATH"
pushd "$BOLOS_SDK_S_PATH" || exit
git checkout $BOLOS_SDK_S_GIT_HASH
popd || exit

echo "Making sure $TMP_HEADERS_PATH exists"
mkdir -p $TMP_HEADERS_PATH || true

echo "Copying necessary header files..."
docker run --rm \
    -d --log-driver=none \
    -v "$TMP_HEADERS":/shared \
    "$DOCKER_IMAGE" \
    "cp -r /opt/bolos/$GCC_BOLOS_PATH/arm-none-eabi/include /shared/arm-none-eabi/"

echo "Cleaning up old Nano X bindings and regenerating them"

rm ../src/bindings/bindingsX.rs || true
bindgen --use-core \
        --with-derive-default \
        --ctypes-prefix cty \
        -o ../src/bindings/bindingsX.rs \
        ../bindgen/wrapperX.h -- \
        -I"$BOLOS_SDK_X_PATH"/include \
        -I"$BOLOS_SDK_X_PATH"/lib_ux/include \
        -I"$BOLOS_SDK_X_PATH"/lib_cxng/include \
        -I"$TMP_HEADERS_PATH"/include \
        -I../bindgen/include \
        -target thumbv6-none-eabi \
        -mcpu=cortex-m0 -mthumb

echo "Cleaning up old Nano S bindings and regenerating them"

rm ../src/bindings/bindingsS.rs || true
bindgen --use-core \
        --with-derive-default \
        --ctypes-prefix cty \
        -o ../src/bindings/bindingsS.rs \
        ../bindgen/wrapperS.h -- \
        -I"$BOLOS_SDK_S_PATH"/include \
        -I"$BOLOS_SDK_S_PATH"/lib_ux/include \
        -I"$BOLOS_SDK_S_PATH"/lib_cxng/include \
        -I"$TMP_HEADERS_PATH"/include \
        -I../bindgen/include \
        -target thumbv6-none-eabi \
        -mcpu=cortex-m0 -mthumb

echo "Done!"

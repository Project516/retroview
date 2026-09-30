#!/bin/sh

# Formats the shader sources in place with clang-format.
# Pass --check to report problems without writing.
# Set CLANG_FORMAT to pick a version, e.g. CLANG_FORMAT=clang-format-18.

: "${CLANG_FORMAT:=clang-format}"

if [ "$1" = "--check" ]; then
    shift
    set -- --dry-run --Werror "$@"
else
    set -- -i "$@"
fi

find shaders -type f \( -name '*.fsh' -o -name '*.vsh' -o -name '*.glsl' \) -exec "$CLANG_FORMAT" "$@" -- {} +

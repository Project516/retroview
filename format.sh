#!/bin/sh

# Formats the shader sources with clang-format. Extra arguments go to
# clang-format, so CI can check without writing: ./format.sh --dry-run --Werror

find shaders -type f \( -name '*.fsh' -o -name '*.vsh' -o -name '*.glsl' \) -exec clang-format "$@" -- {} +
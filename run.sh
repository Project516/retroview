#!/bin/bash

export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"

sdk install java 25.0.3-tem < /dev/null || true
sdk use java 25.0.3-tem

./clean.sh
./gradlew build runShaderClient
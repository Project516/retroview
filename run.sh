#!/bin/bash

export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"

sdk use java 21.0.10-tem

./clean.sh
./gradlew build runShaderClient
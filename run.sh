#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

build_app() {
    xcodebuild -quiet -scheme Speak2 -destination 'platform=macOS' -derivedDataPath .build/xcode build
}

if [[ "${1:-}" == "setup" ]]; then
    echo "Installing Apple's Metal Toolchain required by MLX..."
    xcodebuild -downloadComponent MetalToolchain
    echo "Performing the initial Xcode build (this can take a while)..."
    build_app
    echo "Setup complete. Run ./run.sh to launch Speak2."
    exit 0
fi

if [[ $# -ne 0 ]]; then
    echo "Usage: $0 [setup]" >&2
    exit 2
fi

# Rebuild incrementally, then launch the binary directly.
build_app
exec .build/xcode/Build/Products/Debug/Speak2

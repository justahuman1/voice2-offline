#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

if [[ $# -gt 1 ]]; then
    echo "Usage: $0 [setup|debug]" >&2
    exit 2
fi

configuration=Release
case "${1:-}" in
    ""|setup) ;;
    debug) configuration=Debug ;;
    *) echo "Usage: $0 [setup|debug]" >&2; exit 2 ;;
esac

build_app() {
    echo "Building Speak2 ($configuration)..."
    xcodebuild -quiet -scheme Speak2 -configuration "$configuration" -destination 'platform=macOS' -derivedDataPath .build/xcode build
}

if [[ "${1:-}" == "setup" ]]; then
    echo "Installing Apple's Metal Toolchain required by MLX..."
    xcodebuild -downloadComponent MetalToolchain
    echo "Performing the initial Xcode build (this can take a while)..."
    build_app
    echo "Setup complete. Run ./run.sh to launch Speak2."
    exit 0
fi

# Optimize Swift inference/graph-building work for normal use; keep Debug explicit.
# Rebuild incrementally, then launch the binary directly.
build_app
echo "Launching Speak2 ($configuration)..."
exec ".build/xcode/Build/Products/$configuration/Speak2"

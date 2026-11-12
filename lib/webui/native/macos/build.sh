#!/bin/zsh
# Builds the helper for developers and startup recovery after lib replacement.
set -euo pipefail
cd "${0:A:h}"
module_cache=$(mktemp -d "${TMPDIR:-/tmp}/lich-webui-module-cache.XXXXXX")
trap 'rm -rf "$module_cache"; rm -f build/LichWebUI-arm64 build/LichWebUI-x86_64 build/LichWebUI.universal' EXIT
mkdir -p build/LichWebUI.app/Contents/MacOS build/LichWebUI.app/Contents/Resources
for architecture in arm64 x86_64; do
  xcrun swiftc -O -target "${architecture}-apple-macos14.0" \
    -module-cache-path "$module_cache" Host.swift ExternalLinks.swift -o "build/LichWebUI-${architecture}"
done
xcrun lipo -create build/LichWebUI-arm64 build/LichWebUI-x86_64 \
  -output build/LichWebUI.universal
cp Info.plist build/LichWebUI.app/Contents/Info.plist
cp window.js build/LichWebUI.app/Contents/Resources/window.js
xcrun lipo -info build/LichWebUI.universal
# Publish the executable last so startup never reuses a partly built bundle.
mv build/LichWebUI.universal build/LichWebUI.app/Contents/MacOS/LichWebUI

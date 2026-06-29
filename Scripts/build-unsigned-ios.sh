#!/usr/bin/env bash
set -euo pipefail

SCHEME="${SCHEME:-SwiftTunnel}"
PROJECT="${PROJECT:-SwiftTunnel.xcodeproj}"
DERIVED_DATA="${DERIVED_DATA:-build/DerivedData}"

xcodebuild build \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  -derivedDataPath "$DERIVED_DATA"

echo "Build products:"
find "$DERIVED_DATA/Build/Products/Release-iphoneos" -maxdepth 2 -name "*.app" -print


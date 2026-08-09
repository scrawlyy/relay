#!/usr/bin/env bash
# Prepares app/ios for building with Xcode.
#
# Prerequisites (macOS): Xcode 16+, xcodegen (brew install xcodegen), Flutter
# SDK, and the engine framework built by `make libbox-ios` in engine/.
set -euo pipefail

cd "$(dirname "$0")/../../.."

if [ ! -d engine/bin/Libbox.xcframework ]; then
  echo "error: engine/bin/Libbox.xcframework not found." >&2
  echo "  Build it first: cd engine && make libbox-ios" >&2
  exit 1
fi

echo "==> Copying engine framework into app/ios"
rm -rf app/ios/Libbox.xcframework
cp -R engine/bin/Libbox.xcframework app/ios/Libbox.xcframework

echo "==> Copying haptic plugin Swift source into the Runner target"
cp packages/haptic_engine/ios/Classes/HapticEnginePlugin.swift app/ios/Runner/HapticEnginePlugin.swift

echo "==> Materializing Flutter iOS artifacts"
(cd app && flutter precache --ios && flutter pub get && flutter build ios --config-only --no-codesign)

echo "==> Linking Flutter.framework into app/ios/Flutter"
mkdir -p app/ios/Flutter
FLUTTER_FRAMEWORK="$FLUTTER_ROOT/bin/cache/artifacts/engine/ios/Flutter.xcframework/ios-arm64/Flutter.framework"
if [ -d "$FLUTTER_FRAMEWORK" ]; then
  ln -sfn "$FLUTTER_FRAMEWORK" app/ios/Flutter/Flutter.framework
else
  echo "warning: Flutter.framework not found at $FLUTTER_FRAMEWORK" >&2
fi

echo "==> Generating Xcode project"
(cd app/ios && xcodegen generate)

echo "Done. Open app/ios/Relay.xcodeproj and run the Runner scheme."

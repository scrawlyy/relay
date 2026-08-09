# Building Relay

All build steps produce artifacts that must exist before the app builds. The
engine is required by both platforms; build it first.

## Prerequisites

| Tool        | Version        | Used for            |
|-------------|----------------|---------------------|
| Go          | 1.24+          | engine              |
| gomobile    | latest         | engine bind         |
| Flutter     | stable (3.27+) | app, plugins        |
| Xcode 16+   | macOS only     | iOS                 |
| xcodegen    | 2.40+ (macOS)  | iOS project gen     |
| JDK 17      | Android only   | Android build       |
| Android SDK | API 35 + NDK   | Android build       |

## 0. One-time host scaffolding

The `app/android` and `app/ios` trees contain the hand-authored sources. The
Gradle wrapper / `local.properties` and other Flutter-generated bits are created
by the Flutter tool — run this once per machine:

```sh
cd app
flutter create --platforms=android --org dev.relay --project-name relay_app .
flutter pub get
```

`flutter create` only fills in missing files, it never overwrites existing
sources.

## 1. Engine (embedded sing-box wrapper)

```sh
cd engine
make tidy        # go mod tidy, fills go.sum (needs network)
make test        # runs the probe/ping/config tests
make libbox-ios      # macOS only -> bin/Libbox.xcframework
make libbox-android  # needs NDK -> bin/Libbox.aar
```

- Swift module: `Libbox` (`import Libbox`)
- Java package: `libbox` (`import libbox.Libbox`)

## 2. Android

```sh
cd app
flutter pub get
flutter build apk --release -PrelayEngineAarPath=/abs/path/engine/bin/Libbox.aar
```

The `vpn_platform` plugin resolves the AAR relative to the app's Gradle root
project; override with `-PrelayEngineAarPath` when the engine lives elsewhere.

### Android specifics

- `VpnTunnelService` (in `packages/vpn_platform/android/.../dev/relay/vpn/`)
  runs the engine in-process; the plugin merges its manifest (permissions,
  `foregroundServiceType="vpn"`, service).
- Min SDK 30 (Android 11), target SDK 35.
- Android 14+ requires `FOREGROUND_SERVICE_VPN` (declared in the plugin
  manifest) and the service must call `startForeground` with type VPN.

## 3. iOS

```sh
cd app/ios/scripts && ./setup_ios.sh   # macOS only
open app/ios/Relay.xcodeproj
```

`setup_ios.sh` copies `engine/bin/Libbox.xcframework` into `app/ios/`,
materializes the Flutter iOS artifacts (`flutter build ios --config-only`),
symlinks `Flutter.framework`, copies the haptic plugin's Swift source into the
Runner target, and runs `xcodegen` to generate `Relay.xcodeproj`.

### iOS specifics

- App bundle id: `dev.relay.app`; extension: `dev.relay.app.tunnel`.
- Both targets carry the `com.apple.developer.networking.networkextension`
  (`packet-tunnel-provider`) and `group.dev.relay` app-group entitlements.
- The extension (`PacketTunnelProvider`) creates the utun fd, starts the
  engine with the profile from `NETunnelProviderProtocol.providerConfiguration`,
  and answers `sendProviderMessage` commands (`stats`, `probe|<timeout>|<url>`).
- The app process runs `tcpPing`/`probeProxy` directly via the Libbox framework
  (no tunnel required); `probeTunnel` and stats are routed to the extension.
- Plugins are pod-free: the haptic Swift source is compiled into the Runner
  target and registered manually in `AppDelegate.swift`; the Android Kotlin
  plugins are auto-registered by the Flutter embedding.

## Signing

- **iOS**: set your `DEVELOPMENT_TEAM` in `app/ios/project.yml` (or Xcode).
  Provisioning must include the Packet-Tunnel entitlement — it is issued
  automatically for your team, no special Apple request needed. Use a
  distribution profile for the extension + app pair.
- **Android**: place `key.properties` in `app/android/` (see `.gitignore`) or
  inject `KEYSTORE_*` env vars in CI. Sign the release build for Play Store.

## CI

- `ci/workflows/engine.yml` — Go vet/test on `engine/` changes.
- `ci/workflows/android.yml` — engine AAR → analyze → test → debug APK.
- `ci/workflows/ios.yml` — macOS: engine xcframework → xcodegen → simulator build.

# Relay — Cross-Platform Proxy Client (iOS + Android)

A premium, minimalist mobile app that tunnels all device traffic through a
user-configured **SOCKS5** or **HTTP** proxy using the native VPN stacks
(Network Extension on iOS, VpnService on Android).

- **UI**: Flutter (Dart 3) — custom, animation-rich, haptics-first design.
- **Engine**: embedded **sing-box** (Go, GPL-3.0) via `gomobile` — battle-tested
  TUN + SOCKS/HTTP outbounds, built-in Clash API for real-time stats.
- **Diagnostics**: functional **through-proxy probe** (proves the proxy actually
  forwards traffic, not merely that the port responds), plus raw TCP ping.

> **License flag**: embedding sing-box (GPL-3.0) means the app must be
> distributed under a GPL-compatible license. Resolve before store submission.
> See `docs/ARCHITECTURE.md` §2.

## Repository layout

```
app/                 Flutter application (lib/ sources, android/ and ios/ hosts)
packages/haptic_engine/   MethodChannel plugin — Taptic / Android haptics
packages/vpn_platform/    MethodChannel + EventChannel plugin — VPN control,
                          stats, diagnostics (Android impl + VpnTunnelService)
engine/              Go module — libbox wrapper around sing-box experimental/libbox
ci/                  GitHub Actions workflows
docs/                BUILD.md, ARCHITECTURE.md, DIAGNOSTICS.md
```

Layout note: `app/android` and `app/ios` are the Flutter host projects (Flutter
requires these exact paths). The xcodegen spec, entitlements and PacketTunnel
extension sources live under `app/ios/`.

## Requirements

- Flutter 3.x stable (Dart 3)
- Go 1.24+ and `golang.org/x/mobile/cmd/gomobile`
- macOS + Xcode for iOS builds (this repo was authored on Windows; iOS builds run via CI)
- Android Studio / Gradle 8 for Android

## Quick start (dev)

```sh
# 1. Build the engine artifacts (do this before building the apps)
cd engine
go mod tidy
make libbox-ios      # requires macOS
make libbox-android  # requires Android NDK

# 2. Plugins
cd ../../packages/haptic_engine && flutter pub get
cd ../vpn_platform && flutter pub get

# 3. App
cd ../../app && flutter pub get && flutter run
```

See `docs/BUILD.md` for the full walkthrough, entitlements, signing, and CI.

## Diagnostics: how "ping" works

The requirement is strict: a check must prove the proxy is **working** — traffic
actually flows through it — not merely that its TCP port responds. The engine's
`ProxyProbe` (engine/libbox/proxycheck.go) does exactly that:

1. **Functional proxy probe (primary)** — dials the proxy, performs the full
   protocol handshake (SOCKS5 RFC 1928/1929 with optional auth, or HTTP
   `CONNECT` with Basic auth), then sends a real probe request **through** the
   tunnel and validates the HTTP response. `Ok=true` only if the proxy forwards
   end-to-end traffic. Reports `connectRTT`, `totalRTT`, HTTP status.
2. **Through-tunnel probe** — when the VPN is active, live latency is measured
   through the running tunnel via sing-box's URL-test (Clash API
   `/proxies/proxy/delay`); a failure renders as an error, never as "latency".
3. **TCP ping (reachability only)** — raw TCP handshake RTT to `host:port`,
   explicitly labeled as not proving the proxy works.

Full semantics and the platform plumbing: `docs/DIAGNOSTICS.md`.

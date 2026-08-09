# Relay — architecture

Premium minimal proxy client: iOS + Android, embedded sing-box engine, native
VPN integration, real-time traffic stats, and functional network diagnostics.

## Layers

```
┌────────────────────────────────────────────────────────┐
│ app/  Flutter UI (Dart)                                │
│  providers/  Riverpod state (connection, stats, ...)   │
│  ui/         Dashboard · Profiles · Diagnostics ·      │
│              Settings · Onboarding + shared widgets    │
│  domain/     Profile model + validation                │
│  data/       SharedPreferences + Keychain/Keystore     │
└───────────┬────────────────────────────────────────────┘
            │ MethodChannel / EventChannel
┌───────────▼────────────────────────────────────────────┐
│ packages/vpn_platform  (native VPN glue)               │
│  Dart facade: connect/disconnect/status/stats/probe*   │
│  Android: VpnPlugin + VpnTunnelService + EngineBridge  │
│  iOS:     VpnController (app process) + PacketTunnel   │
│           Provider (extension process)                 │
└───────────┬────────────────────────────────────────────┘
            │ gomobile bind (Libbox.xcframework / Libbox.aar)
┌───────────▼────────────────────────────────────────────┐
│ engine/  Go: proxyclient.dev/engine/libbox             │
│  libbox.go      lifecycle, state, traffic listener     │
│  config.go      sing-box JSON builder (TUN/DNS/route)  │
│  proxycheck.go  functional probe + TCP ping            │
│  tunnel.go      through-tunnel probe (Clash API)       │
│  stats.go       /traffic stream consumer               │
│  platform*.go   PlatformInterface impl (fd passthrough)│
│  sing-box v1.13.16 (GPL-3.0)                           │
└────────────────────────────────────────────────────────┘
```

## Engine ↔ native contract

- **Start**: `Setup(base, working, temp)` → `StartWithConfig(configJSON, tunFd)`.
  The native layer owns the tun fd; the Go platform wrapper dups it.
- **Config**: built by the engine from the profile (SOCKS5/HTTP outbound,
  TUN `mixed` stack, `auto_route`, DoH `https://1.1.1.1/dns-query`, route
  final `proxy`, Clash API on `127.0.0.1:<port>` with a random secret).
- **Stats**: engine streams Clash API `/traffic` deltas, accumulates totals,
  and forwards them to a `TrafficListener`. iOS: the app polls the extension
  at 1 Hz via `sendProviderMessage`; Android: same-process callback → EventChannel.
- **Diagnostics**: see `docs/DIAGNOSTICS.md` — functional through-proxy probe
  is the primary check; TCP ping is reachability-only.

## Process model

| Platform | App process                       | Tunnel process                |
|----------|-----------------------------------|-------------------------------|
| iOS      | UI + `probeProxy`/`tcpPing`       | PacketTunnel extension: engine|
| Android  | UI + engine + `VpnService` (same) | — (same process)              |

## Data & secrets

- Profiles (metadata) in SharedPreferences; passwords in Keychain/Keystore
  (`flutter_secure_storage`), read transiently for connect/probe.
- iOS: profile JSON travels to the extension via
  `NETunnelProviderProtocol.providerConfiguration` (only while starting).
- No accounts, no telemetry, no cloud.

## Threading & battery

- Stats/status EventChannels emit at 1 Hz only while the dashboard is live;
  latency probes every 15 s while connected; nothing runs while disconnected.
- Engine idle work is limited by sing-box; no keep-alive churn.

## Licensing

sing-box is GPL-3.0. The app must be distributed under a GPL-compatible
license; see `README.md` and the Settings > About screen.

# Diagnostics design

The core diagnostic requirement: **a "ping" must prove the proxy is actually
working — traffic must flow through it — not merely that its TCP port responds.**

## The three checks

### 1. Functional proxy check (`probeProxy`) — PRIMARY

Engine: `ProxyProbe` (engine/libbox/proxycheck.go). Steps, all timed:

1. **Dial** the proxy server (TCP connect RTT recorded).
2. **Handshake** — full protocol negotiation:
   - SOCKS5: RFC 1928 greeting (offering `0x00` and `0x02`), RFC 1929
     username/password auth when credentials are present, then a CONNECT to
     the probe target.
   - HTTP: `CONNECT` with `Proxy-Authorization: Basic` when credentials exist.
3. **Probe request through the tunnel** — TLS (for https targets) then a real
   `GET` to the probe endpoint (default `https://www.gstatic.com/generate_204`,
   the same 204 connectivity check Chrome uses).
4. **Validate the response** — success requires HTTP 2xx/3xx.

`Ok = true` therefore means: the proxy accepts connections, authenticates,
forwards TCP, terminates TLS end-to-end, and returns real content. A bare TCP
acceptance (step 1 alone) is never treated as success.

Result fields: `connectRttMs` (dial+handshake), `totalRttMs` (full round trip
including the probe request), `httpStatus`, `error`.

### 2. Server reachability (`tcpPing`) — SECONDARY, clearly labeled

Engine: `TCPPing`. A raw TCP handshake RTT. Can succeed while the proxy is
broken (wrong credentials, no forwarding, blocked egress). The Diagnostics
screen and all UI copy explicitly say it does **not** prove the proxy works.

### 3. Through-tunnel check (`probeTunnel`) — while connected

Engine: `TunnelProbe` via the Clash API URL-test
(`/proxies/{tag}/delay?url=…&timeout=…`), i.e. the running engine tests its own
outbound end-to-end. Only meaningful while the tunnel is up; the Dashboard
latency pill and its periodic 15 s probe use this — a failed probe renders as
an error state, never as "latency".

## Where each is used

| Surface                          | Check                         |
|----------------------------------|-------------------------------|
| Dashboard status + latency pill  | `probeTunnel` (live, 15 s)    |
| Profile editor "Test proxy"      | `probeProxy` (functional)     |
| Diagnostics screen (headline)    | `probeProxy` (functional)     |
| Diagnostics screen (secondary)   | `tcpPing` (reachability)      |
| Diagnostics screen (while on)    | `probeTunnel`                 |

## Platform plumbing

- **Engine** exposes `ProxyProbe`, `TCPPing`, `TunnelProbe` (Go, exported via
  gomobile).
- **Android** (`vpn_platform`): `probeProxy`/`tcpPing` call the Libbox AAR
  in-process; `probeTunnel` calls the engine in-process (same process).
- **iOS** (`VpnController`): `probeProxy`/`tcpPing` call the Libbox framework
  in the app process; `probeTunnel`/`stats` are sent to the extension via
  `sendProviderMessage` (`probe|<timeout>|<url>`, `stats`).
- **Dart** (`VpnPlatform.probeProxy`) documents the semantics so every layer
  carries the same contract.

## Probe endpoint

Configurable in Settings (persisted). Must return 2xx/3xx. Default:
`https://www.gstatic.com/generate_204`.

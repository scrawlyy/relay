package libbox

import (
	"bufio"
	"context"
	"crypto/tls"
	"encoding/base64"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"
)

// TCPPing measures the raw TCP handshake RTT to the proxy server. This proves
// the server is reachable and the port is open — it does NOT prove the proxy
// forwards traffic. Use ProxyProbe for a functional check.
func TCPPing(server string, port int32, timeoutMs int32) (*ProbeResult, error) {
	timeout := durationMs(timeoutMs)
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	start := time.Now()
	dialer := &net.Dialer{Timeout: timeout}
	conn, err := dialer.DialContext(ctx, "tcp", net.JoinHostPort(server, strconv.Itoa(int(port))))
	if err != nil {
		return &ProbeResult{Ok: false, Error: err.Error()}, nil
	}
	_ = conn.Close()
	return &ProbeResult{
		Ok:         true,
		ConnectRTT: msSince(start),
		TotalRTT:   msSince(start),
	}, nil
}

// ProxyProbe performs a functional, end-to-end check of a proxy server: it
// dials the proxy, completes the full protocol handshake (SOCKS5 RFC 1928/1929
// or HTTP CONNECT), then sends a real probe request THROUGH the tunnel and
// validates the response. A success therefore proves the proxy is actually
// forwarding traffic, not merely responding on TCP.
//
// probeURL default: https://www.gstatic.com/generate_204 (returns 204 when the
// proxy is working). Any URL is accepted; http and https schemes supported.
func ProxyProbe(cfg *ProxyConfig, probeURL string, timeoutMs int32) (*ProbeResult, error) {
	if cfg == nil {
		return nil, fmt.Errorf("nil proxy config")
	}
	timeout := durationMs(timeoutMs)
	if probeURL == "" {
		probeURL = "https://www.gstatic.com/generate_204"
	}
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	pu, err := url.Parse(probeURL)
	if err != nil {
		return nil, fmt.Errorf("invalid probe url: %w", err)
	}
	if pu.Scheme != "http" && pu.Scheme != "https" {
		return nil, fmt.Errorf("unsupported probe url scheme %q", pu.Scheme)
	}

	return proxyProbe(ctx, cfg, pu), nil
}

func proxyProbe(ctx context.Context, cfg *ProxyConfig, pu *url.URL) *ProbeResult {
	start := time.Now()
	result := &ProbeResult{}

	targetHost := pu.Hostname()
	targetPort := pu.Port()
	if targetPort == "" {
		if pu.Scheme == "https" {
			targetPort = "443"
		} else {
			targetPort = "80"
		}
	}

	serverAddr := net.JoinHostPort(cfg.Server, strconv.Itoa(int(cfg.Port)))
	dialer := &net.Dialer{}
	conn, err := dialer.DialContext(ctx, "tcp", serverAddr)
	if err != nil {
		return fail(result, err)
	}
	defer conn.Close()
	result.ConnectRTT = msSince(start)

	switch cfg.Type {
	case "socks5", "":
		err = socks5Handshake(conn, cfg, targetHost, targetPort)
	case "http":
		err = httpConnectHandshake(conn, cfg, targetHost, targetPort)
	default:
		return fail(result, fmt.Errorf("unsupported proxy type %q", cfg.Type))
	}
	if err != nil {
		return fail(result, err)
	}

	deadline, hasDeadline := ctx.Deadline()
	if hasDeadline {
		_ = conn.SetDeadline(deadline)
	}

	var probeConn net.Conn = conn
	if pu.Scheme == "https" {
		tlsConn := tls.Client(conn, &tls.Config{ServerName: targetHost, MinVersion: tls.VersionTLS12})
		if err := tlsConn.HandshakeContext(ctx); err != nil {
			return fail(result, err)
		}
		probeConn = tlsConn
	}

	request := fmt.Sprintf(
		"GET %s HTTP/1.1\r\nHost: %s\r\nUser-Agent: relay-probe/1.0\r\nConnection: close\r\n\r\n",
		pu.RequestURI(), pu.Host)
	if _, err := probeConn.Write([]byte(request)); err != nil {
		return fail(result, err)
	}

	resp, err := http.ReadResponse(bufio.NewReader(probeConn), &http.Request{Method: http.MethodGet})
	if err != nil {
		return fail(result, err)
	}
	_, _ = io.Copy(io.Discard, resp.Body)
	_ = resp.Body.Close()

	result.TotalRTT = msSince(start)
	result.HTTPStatus = int32(resp.StatusCode)
	result.Ok = resp.StatusCode >= 200 && resp.StatusCode < 400
	if !result.Ok {
		result.Error = fmt.Sprintf("probe request failed with HTTP %d", resp.StatusCode)
	}
	return result
}

// socks5Handshake performs RFC 1928 negotiation (with RFC 1929 username/password
// auth when credentials are present) and a CONNECT to targetHost:targetPort.
func socks5Handshake(conn net.Conn, cfg *ProxyConfig, targetHost, targetPort string) error {
	// Greeting: offer no-auth (0x00) and username/password (0x02).
	if _, err := conn.Write([]byte{0x05, 0x02, 0x00, 0x02}); err != nil {
		return fmt.Errorf("socks5 greeting: %w", err)
	}
	method := make([]byte, 2)
	if _, err := io.ReadFull(conn, method); err != nil {
		return fmt.Errorf("socks5 method response: %w", err)
	}
	if method[0] != 0x05 {
		return fmt.Errorf("socks5: invalid server version %d", method[0])
	}
	switch method[1] {
	case 0x00:
	case 0x02:
		if err := socks5UserPassAuth(conn, cfg); err != nil {
			return err
		}
	default:
		return fmt.Errorf("socks5: server rejected auth methods (method %d)", method[1])
	}

	port, err := strconv.Atoi(targetPort)
	if err != nil {
		return fmt.Errorf("invalid target port %q", targetPort)
	}
	host := []byte(targetHost)
	if len(host) == 0 || len(host) > 255 {
		return fmt.Errorf("invalid target host %q", targetHost)
	}
	request := []byte{0x05, 0x01, 0x00, 0x03, byte(len(host))}
	request = append(request, host...)
	request = append(request, byte(port>>8), byte(port))
	if _, err := conn.Write(request); err != nil {
		return fmt.Errorf("socks5 connect: %w", err)
	}

	reply := make([]byte, 4)
	if _, err := io.ReadFull(conn, reply); err != nil {
		return fmt.Errorf("socks5 connect response: %w", err)
	}
	if reply[0] != 0x05 {
		return fmt.Errorf("socks5: invalid reply version %d", reply[0])
	}
	if reply[1] != 0x00 {
		return fmt.Errorf("socks5 connect refused: code %d", reply[1])
	}
	// Consume the BND.ADDR/BND.PORT fields.
	switch reply[3] {
	case 0x01:
		_, _ = io.CopyN(io.Discard, conn, 4+2)
	case 0x04:
		_, _ = io.CopyN(io.Discard, conn, 16+2)
	case 0x03:
		var length [1]byte
		if _, err := io.ReadFull(conn, length[:]); err != nil {
			return fmt.Errorf("socks5 bind addr: %w", err)
		}
		_, _ = io.CopyN(io.Discard, conn, int64(length[0])+2)
	default:
		return fmt.Errorf("socks5: invalid atyp %d", reply[3])
	}
	return nil
}

func socks5UserPassAuth(conn net.Conn, cfg *ProxyConfig) error {
	user := []byte(cfg.Username)
	pass := []byte(cfg.Password)
	if len(user) > 255 || len(pass) > 255 {
		return fmt.Errorf("socks5 credentials too long")
	}
	request := []byte{0x01, byte(len(user))}
	request = append(request, user...)
	request = append(request, byte(len(pass)))
	request = append(request, pass...)
	if _, err := conn.Write(request); err != nil {
		return fmt.Errorf("socks5 auth: %w", err)
	}
	var response [2]byte
	if _, err := io.ReadFull(conn, response[:]); err != nil {
		return fmt.Errorf("socks5 auth response: %w", err)
	}
	if response[1] != 0x00 {
		return fmt.Errorf("socks5 authentication failed")
	}
	return nil
}

// httpConnectHandshake establishes an HTTP CONNECT tunnel to targetHost:targetPort.
func httpConnectHandshake(conn net.Conn, cfg *ProxyConfig, targetHost, targetPort string) error {
	target := net.JoinHostPort(targetHost, targetPort)
	var builder strings.Builder
	builder.WriteString("CONNECT " + target + " HTTP/1.1\r\n")
	builder.WriteString("Host: " + target + "\r\n")
	if cfg.Username != "" {
		credentials := base64.StdEncoding.EncodeToString([]byte(cfg.Username + ":" + cfg.Password))
		builder.WriteString("Proxy-Authorization: Basic " + credentials + "\r\n")
	}
	builder.WriteString("\r\n")
	if _, err := conn.Write([]byte(builder.String())); err != nil {
		return fmt.Errorf("http connect: %w", err)
	}
	resp, err := http.ReadResponse(bufio.NewReader(conn), &http.Request{Method: http.MethodConnect})
	if err != nil {
		return fmt.Errorf("http connect response: %w", err)
	}
	_ = resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("http proxy CONNECT failed: HTTP %d", resp.StatusCode)
	}
	return nil
}

func fail(result *ProbeResult, err error) *ProbeResult {
	result.Ok = false
	result.Error = err.Error()
	if result.TotalRTT == 0 {
		result.TotalRTT = result.ConnectRTT
	}
	return result
}

func durationMs(ms int32) time.Duration {
	if ms <= 0 {
		ms = 10000
	}
	return time.Duration(ms) * time.Millisecond
}

func msSince(t time.Time) int64 {
	return time.Since(t).Milliseconds()
}

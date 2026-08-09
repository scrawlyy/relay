package libbox

import (
	"encoding/base64"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

// --- test proxy servers ------------------------------------------------------

// startTarget spins up an HTTP server answering /generate_204 with HTTP 204.
func startTarget(t *testing.T) *httptest.Server {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/generate_204" {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	}))
	t.Cleanup(srv.Close)
	return srv
}

// startSocks5Server runs a minimal RFC 1928 SOCKS5 server (optional RFC 1929
// user/pass auth) that CONNECTs to the requested target and relays bytes.
func startSocks5Server(t *testing.T, username, password string) string {
	t.Helper()
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = listener.Close() })

	go func() {
		for {
			conn, err := listener.Accept()
			if err != nil {
				return
			}
			go handleSocks5(conn, username, password)
		}
	}()
	return listener.Addr().String()
}

func handleSocks5(conn net.Conn, username, password string) {
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(10 * time.Second))

	greeting := make([]byte, 2)
	if _, err := io.ReadFull(conn, greeting); err != nil || greeting[0] != 0x05 {
		return
	}
	methods := make([]byte, int(greeting[1]))
	if _, err := io.ReadFull(conn, methods); err != nil {
		return
	}
	hasAuth := false
	for _, m := range methods {
		if m == 0x02 {
			hasAuth = true
		}
	}
	switch {
	case username == "" && contains(methods, 0x00):
		_, _ = conn.Write([]byte{0x05, 0x00})
	case username != "" && hasAuth:
		_, _ = conn.Write([]byte{0x05, 0x02})
		authHeader := make([]byte, 2)
		if _, err := io.ReadFull(conn, authHeader); err != nil || authHeader[0] != 0x01 {
			return
		}
		user := make([]byte, int(authHeader[1]))
		if _, err := io.ReadFull(conn, user); err != nil {
			return
		}
		var passLen [1]byte
		if _, err := io.ReadFull(conn, passLen[:]); err != nil {
			return
		}
		pass := make([]byte, int(passLen[0]))
		if _, err := io.ReadFull(conn, pass); err != nil {
			return
		}
		if string(user) != username || string(pass) != password {
			_, _ = conn.Write([]byte{0x01, 0x01})
			return
		}
		_, _ = conn.Write([]byte{0x01, 0x00})
	default:
		_, _ = conn.Write([]byte{0x05, 0xFF})
		return
	}

	request := make([]byte, 4)
	if _, err := io.ReadFull(conn, request); err != nil || request[0] != 0x05 || request[1] != 0x01 {
		return
	}
	var host string
	var port int
	switch request[3] {
	case 0x01:
		ip := make([]byte, 4)
		if _, err := io.ReadFull(conn, ip); err != nil {
			return
		}
		host = net.IP(ip).String()
	case 0x03:
		var l [1]byte
		if _, err := io.ReadFull(conn, l[:]); err != nil {
			return
		}
		name := make([]byte, int(l[0]))
		if _, err := io.ReadFull(conn, name); err != nil {
			return
		}
		host = string(name)
	default:
		return
	}
	p := make([]byte, 2)
	if _, err := io.ReadFull(conn, p); err != nil {
		return
	}
	port = int(p[0])<<8 | int(p[1])

	upstream, err := net.Dial("tcp", net.JoinHostPort(host, fmt.Sprint(port)))
	if err != nil {
		_, _ = conn.Write([]byte{0x05, 0x05, 0x00, 0x01, 0, 0, 0, 0, 0, 0})
		return
	}
	defer upstream.Close()
	_, _ = conn.Write([]byte{0x05, 0x00, 0x00, 0x01, 0, 0, 0, 0, 0, 0})

	done := make(chan struct{}, 2)
	go func() { _, _ = io.Copy(upstream, conn); done <- struct{}{} }()
	go func() { _, _ = io.Copy(conn, upstream); done <- struct{}{} }()
	<-done
}

func contains(s []byte, v byte) bool {
	for _, x := range s {
		if x == v {
			return true
		}
	}
	return false
}

// startHTTPProxyServer runs a minimal HTTP CONNECT proxy.
func startHTTPProxyServer(t *testing.T, username, password string) string {
	t.Helper()
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = listener.Close() })

	go func() {
		for {
			conn, err := listener.Accept()
			if err != nil {
				return
			}
			go handleHTTPConnect(conn, username, password)
		}
	}()
	return listener.Addr().String()
}

func handleHTTPConnect(conn net.Conn, username, password string) {
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(10 * time.Second))

	buf := make([]byte, 0, 4096)
	tmp := make([]byte, 1024)
	headerEnd := -1
	for headerEnd < 0 {
		n, err := conn.Read(tmp)
		if err != nil {
			return
		}
		buf = append(buf, tmp[:n]...)
		headerEnd = strings.Index(string(buf), "\r\n\r\n")
		if len(buf) > 64*1024 {
			return
		}
	}
	header := string(buf[:headerEnd])
	lines := strings.Split(header, "\r\n")
	if len(lines) == 0 || !strings.HasPrefix(lines[0], "CONNECT ") {
		_, _ = conn.Write([]byte("HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\n\r\n"))
		return
	}
	if username != "" {
		expected := "Basic " + base64.StdEncoding.EncodeToString([]byte(username+":"+password))
		ok := false
		for _, line := range lines[1:] {
			if strings.EqualFold(line, "Proxy-Authorization: "+expected) {
				ok = true
				break
			}
		}
		if !ok {
			_, _ = conn.Write([]byte("HTTP/1.1 407 Proxy Authentication Required\r\nContent-Length: 0\r\n\r\n"))
			return
		}
	}
	target := strings.TrimSpace(strings.TrimPrefix(lines[0], "CONNECT "))
	upstream, err := net.Dial("tcp", target)
	if err != nil {
		_, _ = conn.Write([]byte("HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\n\r\n"))
		return
	}
	defer upstream.Close()
	_, _ = conn.Write([]byte("HTTP/1.1 200 Connection Established\r\n\r\n"))

	done := make(chan struct{}, 2)
	go func() { _, _ = io.Copy(upstream, conn); done <- struct{}{} }()
	go func() { _, _ = io.Copy(conn, upstream); done <- struct{}{} }()
	<-done
}

// --- tests -------------------------------------------------------------------

func TestProxyProbeSOCKS5NoAuth(t *testing.T) {
	target := startTarget(t)
	proxyHost, proxyPort := splitAddr(t, startSocks5Server(t, "", ""))

	cfg := &ProxyConfig{Type: "socks5", Server: proxyHost, Port: proxyPort}
	result, err := ProxyProbe(cfg, target.URL+"/generate_204", 5000)
	if err != nil {
		t.Fatal(err)
	}
	if !result.Ok {
		t.Fatalf("expected ok, got error=%q status=%d", result.Error, result.HTTPStatus)
	}
	if result.HTTPStatus != 204 {
		t.Fatalf("expected HTTP 204, got %d", result.HTTPStatus)
	}
	if result.TotalRTT <= 0 {
		t.Fatalf("expected positive total rtt, got %d", result.TotalRTT)
	}
}

func TestProxyProbeSOCKS5WithAuth(t *testing.T) {
	target := startTarget(t)
	proxyHost, proxyPort := splitAddr(t, startSocks5Server(t, "alice", "s3cret"))

	cfg := &ProxyConfig{Type: "socks5", Server: proxyHost, Port: proxyPort, Username: "alice", Password: "s3cret"}
	result, err := ProxyProbe(cfg, target.URL+"/generate_204", 5000)
	if err != nil {
		t.Fatal(err)
	}
	if !result.Ok {
		t.Fatalf("expected ok with valid credentials, got %q", result.Error)
	}
}

func TestProxyProbeSOCKS5WrongPassword(t *testing.T) {
	target := startTarget(t)
	proxyHost, proxyPort := splitAddr(t, startSocks5Server(t, "alice", "s3cret"))

	cfg := &ProxyConfig{Type: "socks5", Server: proxyHost, Port: proxyPort, Username: "alice", Password: "wrong"}
	result, err := ProxyProbe(cfg, target.URL+"/generate_204", 5000)
	if err != nil {
		t.Fatal(err)
	}
	if result.Ok {
		t.Fatal("expected failure with wrong password")
	}
}

func TestProxyProbeHTTPConnect(t *testing.T) {
	target := startTarget(t)
	proxyHost, proxyPort := splitAddr(t, startHTTPProxyServer(t, "bob", "pw"))

	cfg := &ProxyConfig{Type: "http", Server: proxyHost, Port: proxyPort, Username: "bob", Password: "pw"}
	result, err := ProxyProbe(cfg, target.URL+"/generate_204", 5000)
	if err != nil {
		t.Fatal(err)
	}
	if !result.Ok {
		t.Fatalf("expected ok, got %q", result.Error)
	}
	if result.HTTPStatus != 204 {
		t.Fatalf("expected HTTP 204, got %d", result.HTTPStatus)
	}
}

func TestProxyProbeRefused(t *testing.T) {
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	host, port := splitAddr(t, listener.Addr().String())
	_ = listener.Close() // nothing listening

	cfg := &ProxyConfig{Type: "socks5", Server: host, Port: port}
	result, err := ProxyProbe(cfg, "https://www.gstatic.com/generate_204", 3000)
	if err != nil {
		t.Fatal(err)
	}
	if result.Ok {
		t.Fatal("expected failure against a closed port")
	}
	if result.Error == "" {
		t.Fatal("expected an error message")
	}
}

func TestTCPPingOpenAndClosed(t *testing.T) {
	proxyHost, proxyPort := splitAddr(t, startSocks5Server(t, "", ""))
	open, err := TCPPing(proxyHost, proxyPort, 3000)
	if err != nil {
		t.Fatal(err)
	}
	if !open.Ok || open.ConnectRTT <= 0 {
		t.Fatalf("expected open port to ping ok, got %+v", open)
	}

	closed, err := TCPPing("127.0.0.1", 1, 3000)
	if err != nil {
		t.Fatal(err)
	}
	if closed.Ok {
		t.Fatal("expected port 1 to be closed")
	}
}

func TestBuildConfigAndParse(t *testing.T) {
	cfg := &ProxyConfig{Type: "http", Server: "10.0.0.5", Port: 8080, Username: "u", Password: "p"}
	configJSON := BuildConfig(cfg, 45678, "topsecret", DefaultMTUiOS)

	host, secret, tag := parseController(configJSON)
	if host != "127.0.0.1:45678" {
		t.Fatalf("unexpected controller host %q", host)
	}
	if secret != "topsecret" {
		t.Fatalf("unexpected secret %q", secret)
	}
	if tag != "proxy" {
		t.Fatalf("unexpected tag %q", tag)
	}
}

func splitAddr(t *testing.T, addr string) (string, int32) {
	t.Helper()
	host, portStr, err := net.SplitHostPort(addr)
	if err != nil {
		t.Fatal(err)
	}
	var port int32
	if _, err := fmt.Sscanf(portStr, "%d", &port); err != nil {
		t.Fatal(err)
	}
	return host, port
}

// Package libbox exposes the tunnel engine to the iOS/Android apps through
// gomobile bind. It wraps sing-box's experimental/libbox (the same library the
// official sing-box clients embed) with a small, versioned API surface.
//
// The native app is responsible for:
//   - creating the TUN file descriptor (iOS: utun via Network Extension;
//     Android: VpnService.Builder.establish())
//   - calling Setup once, then StartWithConfig with the fd
//   - consuming traffic stats via SetTrafficListener and control via the
//     exported Probe/Ping functions
package libbox

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"net"
	"runtime"
	"strconv"
	"sync"
	"syscall"

	sblib "github.com/sagernet/sing-box/experimental/libbox"
)

// Engine states reported by GetState.
const (
	StateStopped  = "stopped"
	StateStarting = "starting"
	StateStarted  = "started"
	StateStopping = "stopping"
	StateFailed   = "failed"
)

// ProxyConfig describes a user-configured proxy server (SOCKS5 or HTTP).
type ProxyConfig struct {
	Type     string // "socks5" | "http"
	Server   string // IP address or hostname
	Port     int32
	Username string
	Password string
}

// ProbeResult is the outcome of a diagnostic probe. ConnectRTT covers the TCP
// dial + protocol handshake; TotalRTT covers the full round-trip including the
// probe request sent THROUGH the tunnel (for ProxyProbe/TunnelProbe).
type ProbeResult struct {
	Ok         bool
	ConnectRTT int64 // milliseconds
	TotalRTT   int64 // milliseconds
	HTTPStatus int32
	Error      string
}

// TrafficListener receives accumulated traffic totals (bytes) roughly once per
// second while the engine is running.
type TrafficListener interface {
	OnTraffic(uplink int64, downlink int64)
}

var (
	engineAccess     sync.Mutex
	server           *sblib.CommandServer
	platform         *platformImpl
	engineState      = StateStopped
	lastConfigJSON   string
	controllerHost   string
	controllerSecret string
	outboundTag      string

	trafficAccess   sync.Mutex
	uplinkTotal     int64
	downlinkTotal   int64
	trafficListener TrafficListener
	statsCancel     chan struct{}
)

// Setup initializes the engine's working directories and logging. Call once
// before StartWithConfig. basePath should be a persistent container directory,
// workingPath/tempPath scratch space (iOS: app group container; Android:
// filesDir/cacheDir).
func Setup(basePath string, workingPath string, tempPath string) error {
	return sblib.Setup(&sblib.SetupOptions{
		BasePath:        basePath,
		WorkingPath:     workingPath,
		TempPath:        tempPath,
		FixAndroidStack: runtime.GOOS == "android",
		LogMaxLines:     2000,
	})
}

// StartWithConfig starts the tunnel engine with the given sing-box config and
// the TUN file descriptor created by the native VPN layer. The fd is dup'd by
// the engine; the caller retains ownership and must close it on stop.
func StartWithConfig(configJSON string, tunFd int32) error {
	engineAccess.Lock()
	defer engineAccess.Unlock()

	if server != nil {
		return errors.New("engine already started")
	}
	if configJSON == "" {
		return errors.New("empty config")
	}

	controllerHost, controllerSecret, outboundTag = parseController(configJSON)
	lastConfigJSON = configJSON

	platform = newPlatform(tunFd)
	handler := &commandHandler{}
	s, err := sblib.NewCommandServer(handler, platform)
	if err != nil {
		engineState = StateFailed
		return fmt.Errorf("create command server: %w", err)
	}
	if err := s.Start(); err != nil {
		engineState = StateFailed
		return fmt.Errorf("start command server: %w", err)
	}
	if err := s.StartOrReloadService(configJSON, &sblib.OverrideOptions{}); err != nil {
		s.Close()
		engineState = StateFailed
		return fmt.Errorf("start service: %w", err)
	}

	server = s
	engineState = StateStarted

	trafficAccess.Lock()
	uplinkTotal, downlinkTotal = 0, 0
	trafficAccess.Unlock()
	startStats(controllerHost, controllerSecret)

	return nil
}

// Stop tears down the running engine. Safe to call when not running.
func Stop() error {
	engineAccess.Lock()
	defer engineAccess.Unlock()

	stopStats()
	if server == nil {
		engineState = StateStopped
		return nil
	}
	engineState = StateStopping
	var firstErr error
	if err := server.CloseService(); err != nil {
		firstErr = err
	}
	server.Close()
	server = nil
	platform = nil
	engineState = StateStopped
	return firstErr
}

// GetState returns the current engine state (see State* constants).
func GetState() string {
	engineAccess.Lock()
	defer engineAccess.Unlock()
	return engineState
}

// SetTrafficListener registers a listener receiving accumulated up/down bytes.
// Pass nil to unregister.
func SetTrafficListener(listener TrafficListener) {
	trafficAccess.Lock()
	defer trafficAccess.Unlock()
	trafficListener = listener
}

// GetTraffic returns the accumulated uplink/downlink totals in bytes.
// Updated to return an error as the final return value for gomobile Objective-C compatibility.
func GetTraffic() (int64, int64, error) {
	trafficAccess.Lock()
	defer trafficAccess.Unlock()
	return uplinkTotal, downlinkTotal, nil
}

// AvailablePort returns a free TCP port on loopback (used for the Clash API).
func AvailablePort(startPort int32) (int32, error) {
	for port := int(startPort); port <= 65535; port++ {
		listener, err := net.Listen("tcp", net.JoinHostPort("127.0.0.1", strconv.Itoa(port)))
		if err != nil {
			if errors.Is(err, syscall.EADDRINUSE) {
				continue
			}
			return 0, err
		}
		_ = listener.Close()
		return int32(port), nil
	}
	return 0, errors.New("no available port found")
}

// RandomSecret returns a hex string of `length` random bytes (Clash API secret).
func RandomSecret(length int32) string {
	buf := make([]byte, length)
	if _, err := rand.Read(buf); err != nil {
		return ""
	}
	return hex.EncodeToString(buf)
}

// commandHandler satisfies sblib.CommandServerHandler. We do not use the
// system-proxy / debug surfaces, so the handlers are inert.
type commandHandler struct{}

func (h *commandHandler) ServiceStop() error                   { return nil }
func (h *commandHandler) ServiceReload() error                 { return nil }
func (h *commandHandler) GetSystemProxyStatus() (*sblib.SystemProxyStatus, error) {
	return &sblib.SystemProxyStatus{Available: false, Enabled: false}, nil
}
func (h *commandHandler) SetSystemProxyEnabled(enabled bool) error { return nil }
func (h *commandHandler) WriteDebugMessage(message string)         {}
module proxyclient.dev/engine

go 1.24

// Pin sing-box to a stable release. Bump deliberately; the experimental/libbox
// API surface (SetupOptions, PlatformInterface, CommandServer) is versioned.
require (
	github.com/sagernet/sing-box v1.13.16
	// Pin golang.org/x/mobile to a fixed revision (commit 923679eb55af,
	// 2026-02-09) for reproducible gomobile bind builds.
	// NOTE: sing-box v1.13.16's experimental/libbox/pidfd_android.go
	// go:linknames os.checkPidfdOnce (a Go 1.25+ symbol) to work around the
	// pidfd/SIGSYS issue on Android (sing-box#3233, golang/go#69065).
	// Go >= 1.23's linker rejects linkname references to unexported stdlib
	// symbols ("invalid reference to os.checkPidfdOnce"), so the Android/iOS
	// bind steps pass `-ldflags="-checklinkname=0"` (same fix as sing-box's
	// own builds, see sing-box#3260). Go 1.25.x is still required for the
	// symbol to exist at all.
	golang.org/x/mobile v0.0.0-20260209203831-923679eb55af
)

// Tool dependency for gomobile
tool golang.org/x/mobile/cmd/gomobile

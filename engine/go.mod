module proxyclient.dev/engine

go 1.24

// Pin sing-box to a stable release. Bump deliberately; the experimental/libbox
// API surface (SetupOptions, PlatformInterface, CommandServer) is versioned.
require (
	github.com/sagernet/sing-box v1.13.16
	// Pin golang.org/x/mobile to a fixed revision (commit 923679eb55af,
	// 2026-02-09) for reproducible gomobile bind builds.
	// NOTE: the Android link error "invalid reference to os.checkPidfdOnce" is
	// NOT caused by this pin: sing-box v1.13.16's
	// experimental/libbox/pidfd_android.go go:linknames os.checkPidfdOnce (a
	// Go 1.25+ symbol) on android targets, so the Android bind requires a
	// Go 1.25.x toolchain regardless.
	golang.org/x/mobile v0.0.0-20260209203831-923679eb55af
)

// Tool dependency for gomobile
tool golang.org/x/mobile/cmd/gomobile

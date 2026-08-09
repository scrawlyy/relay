module proxyclient.dev/engine

go 1.24

// Pin sing-box to a stable release. Bump deliberately; the experimental/libbox
// API surface (SetupOptions, PlatformInterface, CommandServer) is versioned.
require (
	github.com/sagernet/sing-box v1.13.16
	// Pin golang.org/x/mobile to the last revision compatible with Go 1.24
	// (commit 923679eb55af, 2026-02-09). Newer revisions require go >= 1.25.0,
	// which forces a toolchain switch in CI and breaks sing-box v1.13.16 at
	// link time ("invalid reference to os.checkPidfdOnce").
	golang.org/x/mobile v0.0.0-20260209203831-923679eb55af
)

// Tool dependency for gomobile
tool golang.org/x/mobile/cmd/gomobile

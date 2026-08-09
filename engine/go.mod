module proxyclient.dev/engine

go 1.24

// Pin sing-box to a stable release. Bump deliberately; the experimental/libbox
// API surface (SetupOptions, PlatformInterface, CommandServer) is versioned.
require github.com/sagernet/sing-box v1.13.16

// Tool dependency for gomobile
tool golang.org/x/mobile/cmd/gomobile

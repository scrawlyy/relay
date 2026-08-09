//go:build !ios

package libbox

// UnderNetworkExtension is false on Android (VpnService runs in the app
// process) and on desktop/dev builds.
func (p *platformImpl) UnderNetworkExtension() bool {
	return false
}

// IncludeAllNetworks is a Network Extension concept; harmless elsewhere.
func (p *platformImpl) IncludeAllNetworks() bool {
	return true
}

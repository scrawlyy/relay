//go:build ios

package libbox

// UnderNetworkExtension reports that the engine runs inside the iOS
// PacketTunnelProvider process (Network Extension).
func (p *platformImpl) UnderNetworkExtension() bool {
	return true
}

// IncludeAllNetworks routes system-wide traffic through the tunnel.
func (p *platformImpl) IncludeAllNetworks() bool {
	return true
}

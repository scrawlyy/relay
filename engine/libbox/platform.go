package libbox

import (
	"errors"

	sblib "github.com/sagernet/sing-box/experimental/libbox"
)

// platformImpl implements sblib.PlatformInterface on the Go side. The native
// app supplies the TUN file descriptor via StartWithConfig; everything else is
// either inert (we do not need per-app/process features in v1) or handled by
// sing-box's own platformInterfaceWrapper (interface naming, monitoring,
// auto-route ranges).
type platformImpl struct {
	tunFd     int32
	myTunName string
}

func newPlatform(tunFd int32) *platformImpl {
	return &platformImpl{tunFd: tunFd}
}

func (p *platformImpl) LocalDNSTransport() sblib.LocalDNSTransport {
	return nil
}

func (p *platformImpl) UsePlatformAutoDetectInterfaceControl() bool {
	return false
}

func (p *platformImpl) AutoDetectInterfaceControl(fd int32) error {
	return nil
}

// OpenTun returns the VPN interface fd created by the native layer.
func (p *platformImpl) OpenTun(options sblib.TunOptions) (int32, error) {
	if p.tunFd <= 0 {
		return 0, errors.New("tun fd not provided")
	}
	return p.tunFd, nil
}

func (p *platformImpl) UseProcFS() bool {
	return false
}

func (p *platformImpl) FindConnectionOwner(ipProtocol int32, sourceAddress string, sourcePort int32, destinationAddress string, destinationPort int32) (*sblib.ConnectionOwner, error) {
	return nil, errors.New("connection owner lookup unsupported")
}

func (p *platformImpl) StartDefaultInterfaceMonitor(listener sblib.InterfaceUpdateListener) error {
	return nil
}

func (p *platformImpl) CloseDefaultInterfaceMonitor(listener sblib.InterfaceUpdateListener) error {
	return nil
}

// GetInterfaces reports no interfaces; with auto_detect_interface the router
// still works through the default interface monitor (inert above).
func (p *platformImpl) GetInterfaces() (sblib.NetworkInterfaceIterator, error) {
	return emptyInterfaceIterator{}, nil
}

func (p *platformImpl) ReadWIFIState() *sblib.WIFIState {
	return nil
}

func (p *platformImpl) SystemCertificates() sblib.StringIterator {
	return emptyStringIterator{}
}

func (p *platformImpl) ClearDNSCache() {}

func (p *platformImpl) SendNotification(notification *sblib.Notification) error {
	return nil
}

type emptyInterfaceIterator struct{}

func (emptyInterfaceIterator) Next() *sblib.NetworkInterface { return nil }
func (emptyInterfaceIterator) HasNext() bool                 { return false }

type emptyStringIterator struct{}

func (emptyStringIterator) Next() string { return "" }
func (emptyStringIterator) HasNext() bool { return false }

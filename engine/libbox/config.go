package libbox

import (
	"encoding/json"
	"fmt"
)

type configOutbound struct {
	Type        string `json:"type"`
	Tag         string `json:"tag"`
	Server      string `json:"server"`
	ServerPort  int32  `json:"server_port"`
	Username    string `json:"username,omitempty"`
	Password    string `json:"password,omitempty"`
}

type configDNSServer struct {
	Tag     string `json:"tag"`
	Address string `json:"address"`
}

type configTunInbound struct {
	Type        string   `json:"type"`
	Tag         string   `json:"tag"`
	MTU         int32    `json:"mtu"`
	AutoRoute   bool     `json:"auto_route"`
	StrictRoute bool     `json:"strict_route"`
	Stack       string   `json:"stack"`
	Address     []string `json:"address"`
}

type configClashAPI struct {
	ExternalController string `json:"external_controller"`
	Secret             string `json:"secret"`
	DefaultMode        string `json:"default_mode"`
}

type engineConfig struct {
	Log struct {
		Level     string `json:"level"`
		Timestamp bool   `json:"timestamp"`
	} `json:"log"`
	DNS struct {
		Servers []configDNSServer `json:"servers"`
		Final   string            `json:"final"`
	} `json:"dns"`
	Inbound  []configTunInbound `json:"inbound"`
	Outbound []configOutbound   `json:"outbound"`
	Route    struct {
		Final               string `json:"final"`
		AutoDetectInterface bool   `json:"auto_detect_interface"`
	} `json:"route"`
	Experimental struct {
		ClashAPI *configClashAPI `json:"clash_api"`
	} `json:"experimental"`
}

// Default MTUs: iOS Network Extension uses 4064 (4096 - UTUN headroom);
// Android VpnService works reliably with 9000.
const (
	DefaultMTUiOS     = 4064
	DefaultMTUAndroid = 9000
)

// BuildConfig renders a complete sing-box configuration for the given proxy
// profile. The tun inbound is injected by the platform wrapper, so only
// address/mtu are honored here. controllerPort/secret configure the Clash API
// used for stats and through-tunnel probes.
func BuildConfig(cfg *ProxyConfig, controllerPort int32, secret string, mtu int32) string {
	if mtu <= 0 {
		mtu = DefaultMTUAndroid
	}
	if cfg == nil {
		cfg = &ProxyConfig{}
	}
	outboundType := cfg.Type
	if outboundType == "" {
		outboundType = "socks"
	}
	outbound := configOutbound{
		Type:       outboundType,
		Tag:        "proxy",
		Server:     cfg.Server,
		ServerPort: cfg.Port,
		Username:   cfg.Username,
		Password:   cfg.Password,
	}

	var cfgObj engineConfig
	cfgObj.Log.Level = "warn"
	cfgObj.Log.Timestamp = true
	cfgObj.DNS.Servers = []configDNSServer{{Tag: "remote", Address: "https://1.1.1.1/dns-query"}}
	cfgObj.DNS.Final = "remote"
	cfgObj.Inbound = []configTunInbound{{
		Type:        "tun",
		Tag:         "tun-in",
		MTU:         mtu,
		AutoRoute:   true,
		StrictRoute: false,
		Stack:       "mixed",
		Address:     []string{"10.7.0.1/32", "fdfe:dcba:9876::1/128"},
	}}
	cfgObj.Outbound = []configOutbound{outbound, {Type: "direct", Tag: "direct"}}
	cfgObj.Route.Final = "proxy"
	cfgObj.Route.AutoDetectInterface = true
	if controllerPort > 0 {
		cfgObj.Experimental.ClashAPI = &configClashAPI{
			ExternalController: fmt.Sprintf("127.0.0.1:%d", controllerPort),
			Secret:             secret,
			DefaultMode:        "global",
		}
	}

	data, err := json.MarshalIndent(cfgObj, "", "  ")
	if err != nil {
		return "{}"
	}
	return string(data)
}

// parseController extracts the Clash API address, secret and route final
// outbound tag from a generated config (used to wire stats + tunnel probes).
func parseController(configJSON string) (host string, secret string, tag string) {
	var raw struct {
		Experimental *struct {
			ClashAPI *struct {
				ExternalController string `json:"external_controller"`
				Secret             string `json:"secret"`
			} `json:"clash_api"`
		} `json:"experimental"`
		Route *struct {
			Final string `json:"final"`
		} `json:"route"`
	}
	if err := json.Unmarshal([]byte(configJSON), &raw); err != nil {
		return "", "", "proxy"
	}
	if raw.Experimental != nil && raw.Experimental.ClashAPI != nil {
		host = raw.Experimental.ClashAPI.ExternalController
		secret = raw.Experimental.ClashAPI.Secret
	}
	tag = "proxy"
	if raw.Route != nil && raw.Route.Final != "" {
		tag = raw.Route.Final
	}
	return host, secret, tag
}

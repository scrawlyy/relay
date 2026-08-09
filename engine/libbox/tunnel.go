package libbox

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"time"
)

// TunnelProbe measures end-to-end latency THROUGH the running tunnel by asking
// sing-box to URL-test the "proxy" outbound (Clash API /proxies/{tag}/delay).
// The probe request is made by the engine through the proxy outbound, so a
// success confirms the tunnel is forwarding traffic right now.
func TunnelProbe(probeURL string, timeoutMs int32) (*ProbeResult, error) {
	engineAccess.Lock()
	host := controllerHost
	secret := controllerSecret
	tag := outboundTag
	running := engineState == StateStarted
	engineAccess.Unlock()

	if !running || host == "" {
		return &ProbeResult{Ok: false, Error: "tunnel is not running"}, nil
	}
	if probeURL == "" {
		probeURL = "https://www.gstatic.com/generate_204"
	}
	timeout := durationMs(timeoutMs)

	endpoint := fmt.Sprintf("http://%s/proxies/%s/delay?url=%s&timeout=%d",
		host, url.PathEscape(tag), url.QueryEscape(probeURL), timeout.Milliseconds())

	req, err := http.NewRequest(http.MethodGet, endpoint, nil)
	if err != nil {
		return nil, err
	}
	if secret != "" {
		req.Header.Set("Authorization", "Bearer "+secret)
	}
	client := &http.Client{Timeout: timeout}
	start := time.Now()
	resp, err := client.Do(req)
	if err != nil {
		return &ProbeResult{Ok: false, Error: err.Error()}, nil
	}
	defer drainAndClose(resp.Body)

	var body struct {
		Delay int64 `json:"delay"`
	}
	_ = json.NewDecoder(resp.Body).Decode(&body)

	result := &ProbeResult{TotalRTT: msSince(start)}
	if resp.StatusCode == http.StatusOK && body.Delay > 0 {
		result.Ok = true
		result.ConnectRTT = body.Delay
		result.TotalRTT = body.Delay
		result.HTTPStatus = http.StatusOK
		return result, nil
	}
	result.Error = fmt.Sprintf("through-tunnel probe failed (HTTP %d)", resp.StatusCode)
	return result, nil
}

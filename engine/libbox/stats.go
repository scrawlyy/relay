package libbox

import (
	"bufio"
	"encoding/json"
	"io"
	"net/http"
	"time"
)

// startStats begins consuming the sing-box Clash API /traffic stream (one JSON
// delta per second) and forwarding accumulated totals to the registered
// TrafficListener. The stream reconnects automatically while the engine runs.
func startStats(controllerHost, secret string) {
	stopStats()
	statsCancel = make(chan struct{})
	if controllerHost == "" {
		return
	}
	go consumeTraffic(controllerHost, secret, statsCancel)
}

// stopStats cancels the traffic consumer goroutine.
func stopStats() {
	if statsCancel != nil {
		close(statsCancel)
		statsCancel = nil
	}
}

func consumeTraffic(controllerHost, secret string, stop <-chan struct{}) {
	client := &http.Client{Timeout: 0}
	baseURL := "http://" + controllerHost + "/traffic"
	for {
		select {
		case <-stop:
			return
		default:
		}
		req, err := http.NewRequest(http.MethodGet, baseURL, nil)
		if err != nil {
			return
		}
		if secret != "" {
			req.Header.Set("Authorization", "Bearer "+secret)
		}
		resp, err := client.Do(req)
		if err != nil {
			if !sleepAbortable(2*time.Second, stop) {
				return
			}
			continue
		}
		scanner := bufio.NewScanner(resp.Body)
		scanner.Buffer(make([]byte, 64*1024), 1024*1024)
		for scanner.Scan() {
			select {
			case <-stop:
				_ = resp.Body.Close()
				return
			default:
			}
			line := scanner.Text()
			if line == "" {
				continue
			}
			var frame struct {
				Up   int64 `json:"up"`
				Down int64 `json:"down"`
			}
			if err := json.Unmarshal([]byte(line), &frame); err != nil {
				continue
			}
			trafficAccess.Lock()
			uplinkTotal += frame.Up
			downlinkTotal += frame.Down
			listener := trafficListener
			up, down := uplinkTotal, downlinkTotal
			trafficAccess.Unlock()
			if listener != nil {
				listener.OnTraffic(up, down)
			}
		}
		_ = resp.Body.Close()
		if !sleepAbortable(2*time.Second, stop) {
			return
		}
	}
}

func sleepAbortable(d time.Duration, stop <-chan struct{}) bool {
	timer := time.NewTimer(d)
	defer timer.Stop()
	select {
	case <-timer.C:
		return true
	case <-stop:
		return false
	}
}

// drainAndClose discards remaining body bytes (helper for probe responses).
func drainAndClose(body io.ReadCloser) {
	_, _ = io.Copy(io.Discard, body)
	_ = body.Close()
}

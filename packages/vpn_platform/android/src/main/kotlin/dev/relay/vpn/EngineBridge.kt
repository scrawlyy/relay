package dev.relay.vpn

import java.util.concurrent.CopyOnWriteArrayList

/**
 * Process-wide state for the tunnel. The engine runs in the same process as
 * the app on Android (VpnService), so the Flutter plugin and the service share
 * this singleton directly.
 */
object EngineBridge {
    enum class State { Disconnected, Connecting, Connected, Disconnecting, Error }

    data class Snapshot(
        val state: State,
        val profileId: String? = null,
        val profileName: String? = null,
        val latencyMs: Long? = null,
    )

    @Volatile
    var state: State = State.Disconnected
        private set

    @Volatile
    var profileId: String? = null
        private set

    @Volatile
    var profileName: String? = null
        private set

    @Volatile
    var latencyMs: Long? = null

    @Volatile
    var uplinkTotal: Long = 0L
        private set

    @Volatile
    var downlinkTotal: Long = 0L
        private set

    private val statusListeners = CopyOnWriteArrayList<(Snapshot) -> Unit>()
    private val statsListeners = CopyOnWriteArrayList<(Long, Long) -> Unit>()

    fun setStatus(newState: State, profileId: String?, profileName: String?) {
        state = newState
        this.profileId = profileId
        this.profileName = profileName
        if (newState != State.Connected) {
            latencyMs = null
        }
        val snapshot = snapshot()
        statusListeners.forEach { it(snapshot) }
    }

    fun snapshot(): Snapshot = Snapshot(state, profileId, profileName, latencyMs)

    /** Called by the engine's TrafficListener with cumulative byte totals. */
    fun onTraffic(uplink: Long, downlink: Long) {
        uplinkTotal = uplink
        downlinkTotal = downlink
        statsListeners.forEach { it(uplink, downlink) }
    }

    fun subscribeStatus(listener: (Snapshot) -> Unit): () -> Unit {
        statusListeners.add(listener)
        return { statusListeners.remove(listener) }
    }

    fun subscribeStats(listener: (Long, Long) -> Unit): () -> Unit {
        statsListeners.add(listener)
        return { statsListeners.remove(listener) }
    }
}

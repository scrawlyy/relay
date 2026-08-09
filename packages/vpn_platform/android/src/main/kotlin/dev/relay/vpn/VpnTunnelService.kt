package dev.relay.vpn

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import libbox.Libbox
import libbox.ProxyConfig
import libbox.TrafficListener
import org.json.JSONObject
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Owns the VPN interface and the embedded engine lifecycle.
 *
 * Flow: onStartCommand(CONNECT) -> foreground -> VpnService.Builder.establish()
 * -> pass the tun fd to the engine (Go dups it; we keep our copy and close it
 * on stop) -> engine starts -> status events flow through [EngineBridge].
 */
class VpnTunnelService : VpnService() {

    companion object {
        const val ACTION_CONNECT = "dev.relay.vpn.CONNECT"
        const val ACTION_STOP = "dev.relay.vpn.STOP"
        const val EXTRA_PROFILE = "profile"
        const val NOTIFICATION_ID = 1001
        const val CHANNEL_ID = "tunnel"
        const val MTU = 9000

        fun connectIntent(context: Context, profileJson: String): Intent =
            Intent(context, VpnTunnelService::class.java)
                .setAction(ACTION_CONNECT)
                .putExtra(EXTRA_PROFILE, profileJson)

        fun stopIntent(context: Context): Intent =
            Intent(context, VpnTunnelService::class.java).setAction(ACTION_STOP)
    }

    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private var tunPfd: ParcelFileDescriptor? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_CONNECT -> {
                ServiceCompat.startForeground(
                    this,
                    NOTIFICATION_ID,
                    buildNotification(),
                    if (Build.VERSION.SDK_INT >= 34) {
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED
                    } else {
                        0
                    },
                )
                val profileJson = intent.getStringExtra(EXTRA_PROFILE) ?: "{}"
                executor.execute { connect(profileJson) }
            }
            ACTION_STOP -> {
                executor.execute { stopEngine() }
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    private fun connect(profileJson: String) {
        val profile = JSONObject(profileJson)
        val profileId = profile.optString("id", "")
        val profileName = profile.optString("name", "Relay")
        EngineBridge.setStatus(EngineBridge.State.Connecting, profileId, profileName)

        try {
            val builder = Builder()
                .setSession(profileName)
                .setMtu(MTU)
                .addAddress("10.7.0.1", 32)
                .addRoute("0.0.0.0", 0)
                .addAddress("fdfe:dcba:9876::1", 128)
                .addRoute("::", 0)
                .setBlockingMode(true)
                .setUnderlyingNetworks(null)

            val fd = builder.establish()
                ?: throw IllegalStateException("VpnService.Builder.establish() returned null")
            tunPfd = fd

            Libbox.Setup(filesDir.absolutePath, filesDir.absolutePath, cacheDir.absolutePath)
            Libbox.SetTrafficListener(object : TrafficListener {
                override fun onTraffic(uplink: Long, downlink: Long) {
                    EngineBridge.onTraffic(uplink, downlink)
                }
            })

            val controllerPort = Libbox.AvailablePort(10000)
            val secret = Libbox.RandomSecret(16)
            val proxy = ProxyConfig()
            proxy.type = profile.optString("protocol", "socks5")
            proxy.server = profile.optString("host", "")
            proxy.port = profile.optInt("port", 0)
            proxy.username = profile.optString("username", "")
            proxy.password = profile.optString("password", "")
            val configJSON = Libbox.BuildConfig(proxy, controllerPort, secret, MTU)

            Libbox.StartWithConfig(configJSON, fd.fd)
            EngineBridge.setStatus(EngineBridge.State.Connected, profileId, profileName)
        } catch (e: Exception) {
            EngineBridge.setStatus(EngineBridge.State.Error, profileId, profileName)
            tunPfd?.close()
            tunPfd = null
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
    }

    private fun stopEngine() {
        try {
            Libbox.Stop()
        } catch (_: Exception) {
        }
        EngineBridge.setStatus(EngineBridge.State.Disconnected, null, null)
    }

    override fun onRevoke() {
        // The OS revoked our VPN (e.g. from system settings). Tear down quietly.
        executor.execute { stopEngine() }
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        executor.execute {
            try {
                Libbox.Stop()
            } catch (_: Exception) {
            }
            EngineBridge.setStatus(EngineBridge.State.Disconnected, null, null)
        }
        executor.shutdown()
        tunPfd?.close()
        tunPfd = null
        super.onDestroy()
    }

    private fun buildNotification(): android.app.Notification {
        createChannel()
        val stopIntent = PendingIntent.getService(
            this,
            0,
            stopIntent(this),
            PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Relay")
            .setContentText("Tunnel active")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setContentIntent(
                PendingIntent.getActivity(
                    this,
                    0,
                    packageManager.getLaunchIntentForPackage(packageName),
                    PendingIntent.FLAG_IMMUTABLE,
                ),
            )
            .addAction(0, "Disconnect", stopIntent)
            .build()
    }

    private fun createChannel() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            "VPN tunnel",
            NotificationManager.IMPORTANCE_LOW,
        )
        channel.setShowBadge(false)
        manager.createNotificationChannel(channel)
    }
}

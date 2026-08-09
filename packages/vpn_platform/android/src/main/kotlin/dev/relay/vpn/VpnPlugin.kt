package dev.relay.vpn

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.VpnService
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import libbox.Libbox
import libbox.ProbeResult
import libbox.ProxyConfig
import org.json.JSONObject
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * MethodChannel/EventChannel bridge between the Flutter app and the tunnel.
 *
 * Diagnostics contract (matches the Dart facade):
 *  - probeProxy  -> FUNCTIONAL through-proxy check (handshake + probe request)
 *  - tcpPing     -> reachability only (TCP handshake RTT)
 *  - probeTunnel -> through the running engine (Clash API URL-test)
 */
class VpnPlugin : FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.ActivityResultListener {

    private var context: Context? = null
    private var activity: Activity? = null
    private var controlChannel: MethodChannel? = null
    private var statusSink: EventChannel.EventSink? = null
    private var statsSink: EventChannel.EventSink? = null
    private var unsubscribeStatus: (() -> Unit)? = null
    private var unsubscribeStats: (() -> Unit)? = null
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()

    private var pendingConnect: Pair<MethodChannel.Result, String>? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        val messenger: BinaryMessenger = binding.binaryMessenger
        controlChannel = MethodChannel(messenger, "dev.relay/vpn").also {
            it.setMethodCallHandler(this)
        }
        EventChannel(messenger, "dev.relay/vpn/status")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    statusSink = events
                    events?.success(EngineBridge.snapshot().toMap())
                    unsubscribeStatus = EngineBridge.subscribeStatus { snapshot ->
                        events?.success(snapshot.toMap())
                    }
                }

                override fun onCancel(arguments: Any?) {
                    unsubscribeStatus?.invoke()
                    unsubscribeStatus = null
                    statusSink = null
                }
            })
        EventChannel(messenger, "dev.relay/vpn/stats")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    statsSink = events
                    unsubscribeStats = EngineBridge.subscribeStats { up, down ->
                        events?.success(
                            mapOf(
                                "upBytes" to up,
                                "downBytes" to down,
                                "latencyMs" to EngineBridge.latencyMs,
                                "ts" to System.currentTimeMillis(),
                            ),
                        )
                    }
                }

                override fun onCancel(arguments: Any?) {
                    unsubscribeStats?.invoke()
                    unsubscribeStats = null
                    statsSink = null
                }
            })
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        controlChannel?.setMethodCallHandler(null)
        controlChannel = null
        unsubscribeStatus?.invoke()
        unsubscribeStats?.invoke()
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "connect" -> handleConnect(call, result)
            "disconnect" -> handleDisconnect(result)
            "getStatus" -> result.success(EngineBridge.snapshot().toMap())
            "tcpPing" -> executor.execute {
                runCatching {
                    val host = call.argument<String>("host") ?: ""
                    val port = (call.argument<Number>("port") ?: 0).toInt()
                    val timeout = (call.argument<Number>("timeoutMs") ?: 5000).toInt()
                    Libbox.TCPPing(host, port, timeout).toMap()
                }.onSuccess { result.success(it) }
                    .onFailure { result.success(probeFailureMap(it.message)) }
            }
            "probeProxy" -> executor.execute {
                runCatching {
                    val profile = call.argument<Map<String, Any?>>("profile") ?: emptyMap()
                    val url = call.argument<String>("probeUrl") ?: ""
                    val timeout = (call.argument<Number>("timeoutMs") ?: 10000).toInt()
                    Libbox.ProxyProbe(profile.toProxyConfig(), url, timeout).toMap()
                }.onSuccess { result.success(it) }
                    .onFailure { result.success(probeFailureMap(it.message)) }
            }
            "probeTunnel" -> executor.execute {
                runCatching {
                    val url = call.argument<String>("probeUrl") ?: ""
                    val timeout = (call.argument<Number>("timeoutMs") ?: 10000).toInt()
                    Libbox.TunnelProbe(url, timeout).toMap()
                }.onSuccess { result.success(it) }
                    .onFailure { result.success(probeFailureMap(it.message)) }
            }
            else -> result.notImplemented()
        }
    }

    // --- connect / consent --------------------------------------------------

    private fun handleConnect(call: MethodCall, result: MethodChannel.Result) {
        val ctx = context ?: run {
            result.success(mapOf("success" to false, "errorCode" to "no_context"))
            return
        }
        val profile = call.argument<Map<String, Any?>>("profile") ?: emptyMap()
        val profileJson = JSONObject(profile).toString()

        val consentIntent = VpnService.prepare(ctx)
        if (consentIntent != null) {
            val act = activity
            if (act == null) {
                result.success(
                    mapOf(
                        "success" to false,
                        "errorCode" to "consent_required",
                        "message" to "VPN permission required",
                    ),
                )
                return
            }
            pendingConnect = result to profileJson
            act.startActivityForResult(consentIntent, REQUEST_PREPARE)
        } else {
            launchService(ctx, profileJson)
            result.success(mapOf("success" to true))
        }
    }

    private fun handleDisconnect(result: MethodChannel.Result) {
        val ctx = context ?: run {
            result.success(mapOf("success" to false, "errorCode" to "no_context"))
            return
        }
        runCatching {
            ctx.startService(VpnTunnelService.stopIntent(ctx))
        }
        result.success(mapOf("success" to true))
    }

    private fun launchService(ctx: Context, profileJson: String) {
        ContextCompat.startForegroundService(ctx, VpnTunnelService.connectIntent(ctx, profileJson))
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_PREPARE) return false
        val pending = pendingConnect ?: return true
        pendingConnect = null
        if (resultCode == Activity.RESULT_OK) {
            launchService(context ?: return true, pending.second)
            pending.first.success(mapOf("success" to true))
        } else {
            pending.first.success(
                mapOf("success" to false, "errorCode" to "consent_denied", "message" to "VPN permission was not granted"),
            )
        }
        return true
    }

    // --- activity wiring ------------------------------------------------------

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    companion object {
        private const val REQUEST_PREPARE = 901

        @JvmStatic
        fun registerWith(registrar: io.flutter.plugin.common.PluginRegistry.Registrar) {
            // Legacy embedding support.
        }
    }
}

private fun EngineBridge.Snapshot.toMap(): Map<String, Any?> = mapOf(
    "state" to state.name.lowercase(),
    "profileId" to profileId,
    "profileName" to profileName,
    "latencyMs" to latencyMs,
)

private fun ProbeResult.toMap(): Map<String, Any?> = mapOf(
    "ok" to ok,
    "connectRttMs" to connectRTT,
    "totalRttMs" to totalRTT,
    "httpStatus" to httpStatus,
    "error" to error,
)

private fun Map<String, Any?>.toProxyConfig(): ProxyConfig = ProxyConfig().apply {
    type = this@toProxyConfig["protocol"] as? String ?: "socks5"
    server = this@toProxyConfig["host"] as? String ?: ""
    port = ((this@toProxyConfig["port"] as? Number) ?: 0).toInt()
    username = this@toProxyConfig["username"] as? String ?: ""
    password = this@toProxyConfig["password"] as? String ?: ""
}

private fun probeFailureMap(message: String?): Map<String, Any?> = mapOf(
    "ok" to false,
    "connectRttMs" to 0,
    "totalRttMs" to 0,
    "httpStatus" to 0,
    "error" to (message ?: "probe failed"),
)

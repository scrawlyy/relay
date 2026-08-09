package dev.relay.haptic

import android.content.Context
import android.os.Build
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class HapticEnginePlugin : FlutterPlugin, MethodCallHandler {
    private var context: Context? = null
    private var channel: MethodChannel? = null
    private var enabled = true

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "dev.relay/haptics").also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "trigger" -> {
                val event = call.argument<String>("event")
                if (event != null) trigger(event)
                result.success(null)
            }
            "setEnabled" -> {
                enabled = call.arguments as? Boolean ?: true
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun trigger(event: String) {
        if (!enabled) return
        val ctx = context ?: return
        val effect = when (event) {
            "connectSuccess" -> VibrationEffect.EFFECT_HEAVY_CLICK
            "connectFail" -> VibrationEffect.EFFECT_DOUBLE_CLICK
            "disconnect" -> VibrationEffect.EFFECT_CLICK
            "toggle" -> VibrationEffect.EFFECT_TICK
            "selection" -> VibrationEffect.EFFECT_TICK
            "error" -> VibrationEffect.EFFECT_DOUBLE_CLICK
            else -> return
        }
        val vibrator: Vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = ctx.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            manager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            ctx.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        val attributes = VibrationAttributes.Builder()
            .setUsage(VibrationAttributes.USAGE_TOUCH)
            .build()
        try {
            vibrator.vibrate(VibrationEffect.createPredefined(effect), attributes)
        } catch (_: Exception) {
            // Fall back to a plain tick on devices without predefined effects.
            vibrator.vibrate(VibrationEffect.createOneShot(15, VibrationEffect.DEFAULT_AMPLITUDE))
        }
    }
}

package com.awfar.cloudcalls

import android.content.Intent
import android.os.Bundle
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val shareChannel = "com.awfar.cloudcalls/share"
    private val headsetEvents = "com.awfar.cloudcalls/headset_events"

    private var headsetSink: EventChannel.EventSink? = null
    private var pendingShare: String? = null
    private var hookDownAt = 0L

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, shareChannel)
            .setMethodCallHandler { _, result -> result.success(null) }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, headsetEvents)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    headsetSink = events
                }

                override fun onCancel(arguments: Any?) {
                    headsetSink = null
                }
            })

        pendingShare?.let {
            sendShare(it)
            pendingShare = null
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleShareIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleShareIntent(intent)
    }

    private fun sendShare(text: String) {
        val engine = flutterEngine
        if (engine != null) {
            MethodChannel(engine.dartExecutor.binaryMessenger, shareChannel)
                .invokeMethod("onShare", text)
        } else {
            pendingShare = text
        }
    }

    private fun handleShareIntent(intent: Intent?) {
        intent ?: return
        when (intent.action) {
            Intent.ACTION_VIEW, Intent.ACTION_DIAL, Intent.ACTION_CALL -> {
                val uri = intent.data ?: return
                if (uri.scheme == "tel") {
                    val num = uri.schemeSpecificPart?.trim()
                        ?: uri.toString().removePrefix("tel:").trim()
                    if (num.isNotEmpty()) sendShare(num)
                }
            }
            Intent.ACTION_SEND -> {
                if (intent.type == "text/plain") {
                    val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return
                    sendShare(text)
                }
            }
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.keyCode == KeyEvent.KEYCODE_HEADSETHOOK ||
            event.keyCode == KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE ||
            event.keyCode == KeyEvent.KEYCODE_CALL
        ) {
            when (event.action) {
                KeyEvent.ACTION_DOWN -> {
                    hookDownAt = System.currentTimeMillis()
                    return true
                }
                KeyEvent.ACTION_UP -> {
                    val duration = System.currentTimeMillis() - hookDownAt
                    val type = if (duration >= 800L) "long" else "short"
                    headsetSink?.success(type)
                    return true
                }
            }
        }
        return super.dispatchKeyEvent(event)
    }
}

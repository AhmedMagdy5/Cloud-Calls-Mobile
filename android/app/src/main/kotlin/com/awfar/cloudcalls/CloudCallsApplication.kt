package com.awfar.cloudcalls

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import id.flutter.flutter_background_service.BackgroundService
import id.flutter.flutter_background_service.WatchdogReceiver

class CloudCallsApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        createBackgroundServiceChannels()
        if (!ENABLE_BACKGROUND_SIP) {
            disableBackgroundService()
        }
    }

    private fun createBackgroundServiceChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return

        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_SIP_SERVICE,
                "SIP connection",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Keeps SIP registration active in the background"
                setShowBadge(false)
            },
        )

        manager.createNotificationChannel(
            NotificationChannel(
                "FOREGROUND_DEFAULT",
                "Background Service",
                NotificationManager.IMPORTANCE_LOW,
            ),
        )
    }

    private fun disableBackgroundService() {
        getSharedPreferences(BACKGROUND_SERVICE_PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean("is_foreground", false)
            .putBoolean("auto_start_on_boot", false)
            .putBoolean("is_manually_stopped", true)
            .apply()

        WatchdogReceiver.remove(this)
        stopService(Intent(this, BackgroundService::class.java))
    }

    companion object {
        // Keep in sync with AppConfig.enableBackgroundSip in lib/core/constants/app_config.dart
        const val ENABLE_BACKGROUND_SIP = false
        const val CHANNEL_SIP_SERVICE = "awfar_sip_service"
        private const val BACKGROUND_SERVICE_PREFS = "id.flutter.background_service"
    }
}

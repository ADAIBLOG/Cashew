package com.budget.tracker_app

import android.content.ComponentName
import android.content.pm.PackageManager
import android.util.Log
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val notificationChannel = "com.budget.tracker_app/notification_listener"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            notificationChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "forceRestartNotificationListener" -> {
                    forceRestartNotificationListener { success ->
                        result.success(success)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Xiaomi HyperOS 等国产 ROM 进入“极限模式/省电模式”后，系统会把
     * NotificationListenerService 解绑，且退出后不会自动重新绑定。
     * 通过先禁用再启用该组件，可强制系统重新绑定通知监听服务，
     * 从而避免用户必须“结束运行后重新打开应用”才能恢复监听。
     */
    private fun forceRestartNotificationListener(callback: (Boolean) -> Unit) {
        Thread {
            val success = try {
                val componentName = ComponentName(
                    packageName,
                    "notification.listener.service.NotificationListener"
                )
                val pm = packageManager
                pm.setComponentEnabledSetting(
                    componentName,
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP
                )
                Thread.sleep(120)
                pm.setComponentEnabledSetting(
                    componentName,
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                    PackageManager.DONT_KILL_APP
                )
                Log.i("CashewNotif", "Notification listener component toggled to force rebind")
                true
            } catch (e: Exception) {
                Log.e("CashewNotif", "Failed to restart notification listener", e)
                false
            }
            runOnUiThread { callback(success) }
        }.start()
    }
}

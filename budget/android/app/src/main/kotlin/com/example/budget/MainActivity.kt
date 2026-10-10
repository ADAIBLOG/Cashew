package com.budget.tracker_app

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val notificationChannel = "com.budget.tracker_app/notification_listener"

    private var pendingTransactionPayload: String? = null

    companion object {
        // 供 TransactionScannerService 等原生组件向 Dart 推送消息使用
        var binaryMessenger: BinaryMessenger? = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 冷启动：仅记录 pending payload，待 Dart 主动拉取
        pendingTransactionPayload = intent.getStringExtra("transaction_payload")
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // 热启动：应用已在运行，直接推送给 Dart
        val payload = intent.getStringExtra("transaction_payload")
        if (payload != null) {
            pendingTransactionPayload = payload
            pushPayloadToDart(payload)
        }
    }

    private fun pushPayloadToDart(payload: String) {
        val messenger = binaryMessenger ?: return
        MethodChannel(messenger, notificationChannel).invokeMethod("onTransactionPayload", payload)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        binaryMessenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            notificationChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "forceRestartNotificationListener" -> {
                    forceRestartNotificationListener { success -> result.success(success) }
                }
                "isNotificationAccessGranted" -> {
                    result.success(isNotificationAccessGranted())
                }
                "openNotificationAccessSettings" -> {
                    openNotificationAccessSettings()
                    result.success(true)
                }
                "getPendingTransactionPayload" -> {
                    val payload = pendingTransactionPayload
                    pendingTransactionPayload = null
                    result.success(payload)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isNotificationAccessGranted(): Boolean {
        val flat = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_NOTIFICATION_LISTENERS,
        ) ?: return false
        val component = ComponentName(this, TransactionScannerService::class.java)
        return flat.split(":").any { it == component.flattenToString() }
    }

    private fun openNotificationAccessSettings() {
        try {
            startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
        } catch (e: Exception) {
            Log.e("CashewNotif", "Failed to open notification access settings", e)
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
                val componentName = ComponentName(this, TransactionScannerService::class.java)
                val pm = packageManager
                pm.setComponentEnabledSetting(
                    componentName,
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP,
                )
                Thread.sleep(120)
                pm.setComponentEnabledSetting(
                    componentName,
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                    PackageManager.DONT_KILL_APP,
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

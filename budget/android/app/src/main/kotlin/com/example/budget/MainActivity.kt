package com.budget.tracker_app

import android.content.ComponentName
import android.content.Intent
import android.os.Build
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
                // 旧方法名保留兼容；行为改为安全的 requestRebind，
                // 不再通过「禁用→启用组件」重绑（部分 ROM 会因此丢掉通知使用权）
                "forceRestartNotificationListener" -> {
                    forceRebindNotificationListener(result)
                }
                "requestNotificationListenerRebind" -> {
                    requestNotificationListenerRebind(result)
                }
                "isNotificationAccessGranted" -> {
                    result.success(isNotificationAccessGranted())
                }
                "getNotificationListenerStatus" -> {
                    result.success(
                        mapOf(
                            "granted" to TransactionScannerService.isAccessGranted(this),
                            "connected" to TransactionScannerService.isConnected(),
                        ),
                    )
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
        return TransactionScannerService.isAccessGranted(this)
    }

    private fun openNotificationAccessSettings() {
        // API 30+ 直接打开本应用的「通知使用权」详情页，用户只需拨一下开关；
        // 部分国产 ROM 没有实现该页面，回落到通知使用权列表。
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                startActivity(
                    Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS).apply {
                        putExtra(
                            Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                            ComponentName(
                                this@MainActivity,
                                TransactionScannerService::class.java,
                            ).flattenToString(),
                        )
                    },
                )
                return
            } catch (e: Exception) {
                Log.w("CashewNotif", "Listener detail settings unavailable, falling back", e)
            }
        }
        try {
            startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
        } catch (e: Exception) {
            Log.e("CashewNotif", "Failed to open notification access settings", e)
        }
    }

    /**
     * 请求系统重新绑定通知监听服务。
     *
     * HyperOS/MIUI 的极限省电、后台清理会在不撤销「通知使用权」的情况下解绑监听服务，
     * 之后重启应用也不会自动绑回来。requestRebind() 是系统提供的官方恢复入口，
     * 比旧实现的「禁用→启用组件」安全（后者在部分 ROM 上会把使用权一起弄丢）。
     */
    private fun requestNotificationListenerRebind(result: MethodChannel.Result) {
        Thread {
            val success = TransactionScannerService.requestRebindNow(this)
            runOnUiThread { result.success(success) }
        }.start()
    }

    /**
     * 普通 requestRebind 没恢复时，走「请求解绑 → 立刻重绑」的完整重连。
     * 不会改动通知使用权；API 34 以下不可用，返回 false 交给上层提示用户。
     */
    private fun forceRebindNotificationListener(result: MethodChannel.Result) {
        Thread {
            val success = TransactionScannerService.forceRebindNow(this)
            runOnUiThread { result.success(success) }
        }.start()
    }
}

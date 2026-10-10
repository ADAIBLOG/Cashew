package com.budget.tracker_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class NotificationBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED &&
            intent.action != Intent.ACTION_MY_PACKAGE_REPLACED &&
            intent.action != "android.intent.action.QUICKBOOT_POWERON" &&
            intent.action != "com.htc.intent.action.QUICKBOOT_POWERON") {
            return
        }
        // 开机/应用更新后，部分国产 ROM 不会自动重新绑定通知监听服务。
        // 若用户已授予通知使用权，这里强制重绑，保证应用不被打开时也能检测通知。
        Log.d("CashewBoot", "Boot or package replace detected, force rebinding notification listener")
        val pendingResult = goAsync()
        Thread {
            try {
                if (TransactionScannerService.isAccessGranted(context)) {
                    TransactionScannerService.forceRebindListener(context)
                }
            } finally {
                pendingResult.finish()
            }
        }.start()
    }
}

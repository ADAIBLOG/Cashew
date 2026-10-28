package com.budget.tracker_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class NotificationBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED &&
            action != "android.intent.action.QUICKBOOT_POWERON" &&
            action != "com.htc.intent.action.QUICKBOOT_POWERON"
        ) {
            return
        }

        // 国产 ROM 开机/应用更新后经常不会自动把 NotificationListenerService 绑回来。
        // 这里主动请求一次重绑；requestRebind 只触发绑定，不会改动「通知使用权」，
        // 因此不会出现「用禁用→启用组件方式重绑反而把权限弄丢」的问题。
        if (TransactionScannerService.isAccessGranted(context)) {
            val requested = TransactionScannerService.requestRebindNow(context)
            Log.d("CashewBoot", "Boot/package-replaced rebind requested: $requested")
        }
    }
}

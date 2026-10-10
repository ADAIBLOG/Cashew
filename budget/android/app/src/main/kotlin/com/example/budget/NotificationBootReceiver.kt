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
        // 不再强制「禁用→启用」监听组件重绑：该操作在部分系统上会撤销通知使用权
        // （正是「自动交易开关自己关闭」的元凶之一）。监听服务是前台常驻服务，
        // 系统开机后会自行恢复绑定；权限状态由应用启动时重新校验。
        Log.d("CashewBoot", "Boot or package replace detected; listener rebind handled by system")
    }
}

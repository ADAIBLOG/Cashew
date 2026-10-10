package com.budget.tracker_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.os.Build
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.util.Locale

/**
 * 纯原生通知监听服务：脱离 Flutter 引擎独立运行。
 * 系统在授予通知使用权后会独立绑定并拉起该服务（应用进程被杀也能继续接收通知）。
 * 这里负责：读取模板 -> 解析通知 -> 原生发出「点击添加」提醒，
 * 点击提醒时通过 int/extra payload 唤起 MainActivity，交由 Dart 打开添加交易页。
 */
class TransactionScannerService : NotificationListenerService() {

    companion object {
        private const val TAG = "CashewNativeScanner"
        private const val CHANNEL_ID = "transaction_scan_channel"
        private const val DB_NAME = "db.sqlite"
        private const val OWN_PACKAGE = "com.budget.tracker_app"
        private const val PAYLOAD_CHANNEL = "com.budget.tracker_app/notification_listener"
        private const val PAYLOAD_EXTRA = "transaction_payload"
        private const val DEDUP_WINDOW_MS = 10 * 60 * 1000L
        private val recentMatches = LinkedHashMap<String, Long>()

        fun isAccessGranted(context: Context): Boolean {
            return try {
                // Settings.Secure.ENABLED_NOTIFICATION_LISTENERS 是 @hide 常量，公开 SDK 编译不到，使用字符串字面量
                val flat = Settings.Secure.getString(
                    context.contentResolver,
                    "enabled_notification_listeners",
                ) ?: return false
                val component = ComponentName(context, TransactionScannerService::class.java)
                flat.split(":").any { it == component.flattenToString() }
            } catch (e: Exception) {
                false
            }
        }

        /**
         * 通过「禁用→启用」监听服务组件，强制系统重新绑定通知监听服务。
         * 用于解决国产 ROM 开机/更新后不自动重绑的问题。
         */
        fun forceRebindListener(context: Context): Boolean {
            return try {
                val componentName = ComponentName(context, TransactionScannerService::class.java)
                val pm = context.packageManager
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
                Log.i(TAG, "Notification listener component toggled to force rebind")
                true
            } catch (e: Exception) {
                Log.e(TAG, "Failed to restart notification listener", e)
                false
            }
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        // 过滤自己应用的通知，避免循环监听
        if (sbn.packageName == OWN_PACKAGE) return
        Thread { handleNotification(applicationContext, sbn) }.start()
    }

    private fun handleNotification(context: Context, sbn: StatusBarNotification) {
        try {
            val message = buildMessage(sbn)
            forwardToDart(message)
            val templates = loadTemplates(context)
            for (template in templates) {
                if (template.ignore) continue
                if (!message.contains(template.contains)) continue

                val amount = getAmount(message, template.amountBefore, template.amountAfter)
                if (amount == null) break

                // 自动模式不需要标题，其余模式按前后定位串提取标题
                val title = if (template.amountBefore == "auto" && template.amountAfter == "auto") {
                    null
                } else {
                    getTitle(message, template.titleBefore, template.titleAfter)
                }

                val key = "${template.pk}_${amount}_${message.hashCode()}"
                if (isDuplicate(key)) return
                markCaptured(key)

                showPromptNotification(context, template.pk, amount, title)
                break
            }
        } catch (e: Exception) {
            Log.e(TAG, "handleNotification error", e)
        }
    }

    private fun buildMessage(sbn: StatusBarNotification): String {
        val extras = sbn.notification?.extras
        val title = extras?.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val content = extras?.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        return "Package name: ${sbn.packageName}\n" +
            "Notification removed: false\n" +
            "\n----\n\n" +
            "Notification Title: $title\n\n" +
            "Notification Content: $content"
    }

    private fun loadTemplates(context: Context): List<Template> {
        val dbDir = context.getDir("flutter", Context.MODE_PRIVATE)
        val dbFile = File(dbDir, DB_NAME)
        if (!dbFile.exists()) return emptyList()

        val list = ArrayList<Template>()
        var db: SQLiteDatabase? = null
        var cursor: Cursor? = null
        try {
            db = SQLiteDatabase.openDatabase(dbFile.absolutePath, null, SQLiteDatabase.OPEN_READONLY)
            cursor = db.rawQuery(
                "SELECT scanner_template_pk, contains, title_transaction_before, " +
                    "title_transaction_after, amount_transaction_before, amount_transaction_after, " +
                    "`ignore` FROM scanner_templates",
                null,
            )
            val idxPk = cursor.getColumnIndex("scanner_template_pk")
            val idxContains = cursor.getColumnIndex("contains")
            val idxTitleBefore = cursor.getColumnIndex("title_transaction_before")
            val idxTitleAfter = cursor.getColumnIndex("title_transaction_after")
            val idxAmountBefore = cursor.getColumnIndex("amount_transaction_before")
            val idxAmountAfter = cursor.getColumnIndex("amount_transaction_after")
            val idxIgnore = cursor.getColumnIndex("ignore")
            while (cursor.moveToNext()) {
                val pk = cursor.getString(idxPk) ?: continue
                val contains = cursor.getString(idxContains) ?: continue
                list.add(
                    Template(
                        pk = pk,
                        contains = contains,
                        titleBefore = cursor.getString(idxTitleBefore) ?: "",
                        titleAfter = cursor.getString(idxTitleAfter) ?: "",
                        amountBefore = cursor.getString(idxAmountBefore) ?: "",
                        amountAfter = cursor.getString(idxAmountAfter) ?: "",
                        ignore = cursor.getInt(idxIgnore) == 1,
                    ),
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "loadTemplates error", e)
        } finally {
            cursor?.close()
            db?.close()
        }
        return list
    }

    private fun getAmount(message: String, before: String, after: String): Double? {
        return try {
            if (before == "auto" && after == "auto") {
                var amount: Double? = null
                amount = parseAmount(Regex("[¥\$€£]\\s*([\\d,]+\\.?\\d*)").find(message)?.groupValues?.getOrNull(1))
                if (amount == null) {
                    amount = parseAmount(Regex("[¥\$€£]([\\d,]+\\.?\\d*)").find(message)?.groupValues?.getOrNull(1))
                }
                if (amount == null) {
                    amount = parseAmount(Regex("([\\d,]+\\.?\\d*)\\s*[¥\$€£元角分]").find(message)?.groupValues?.getOrNull(1))
                }
                amount
            } else {
                val start = message.indexOf(before) + before.length
                if (start < before.length) return null
                val end = message.indexOf(after, start)
                val amountString = message.substring(start, end)
                val clean = amountString
                    .replace(Regex("[\\s]"), "")
                    .replace(Regex("[¥\$€£]"), "")
                    .replace(",", "")
                clean.toDoubleOrNull()
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun parseAmount(raw: String?): Double? {
        if (raw == null) return null
        return raw.replace(",", "").toDoubleOrNull()
    }

    private fun getTitle(message: String, before: String, after: String): String? {
        return try {
            val start = message.indexOf(before) + before.length
            val end = message.indexOf(after, start)
            var title = message.substring(start, end)
            title = title.replace("\n", "")
            title = title.lowercase()
            if (title.isNotEmpty()) {
                title = title.substring(0, 1).uppercase() + title.substring(1)
            }
            title
        } catch (e: Exception) {
            null
        }
    }

    private fun isDuplicate(key: String): Boolean {
        prune()
        return recentMatches.containsKey(key)
    }

    private fun markCaptured(key: String) {
        prune()
        recentMatches[key] = System.currentTimeMillis()
    }

    private fun prune() {
        val now = System.currentTimeMillis()
        val it = recentMatches.entries.iterator()
        while (it.hasNext()) {
            if (now - it.next().value > DEDUP_WINDOW_MS) it.remove()
        }
    }

    private fun showPromptNotification(context: Context, templatePk: String, amount: Double, title: String?) {
        val payload = JSONObject().apply {
            put("type", "addTransaction")
            put("amount", amount.toString())
            put("templatePk", templatePk)
            if (title != null) put("title", title)
        }
        val payloadJson = payload.toString()

        createChannel(context)

        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(PAYLOAD_EXTRA, payloadJson)
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            System.currentTimeMillis().toInt(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        val amountString = String.format(Locale.US, "%.2f", amount)
        builder.setSmallIcon(R.drawable.notification_icon_android2)
            .setContentTitle("检测到交易信息")
            .setContentText("发现一笔金额为${amountString}的交易，点击添加")
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            builder.setPriority(Notification.PRIORITY_HIGH)
        }

        val notificationId = System.currentTimeMillis().toInt()
        nm.notify(notificationId, builder.build())
    }

    private fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                CHANNEL_ID,
                "transaction_scan_channel",
                NotificationManager.IMPORTANCE_HIGH,
            )
            channel.description = "通知扫描交易"
            nm.createNotificationChannel(channel)
        }
    }

    private fun forwardToDart(message: String) {
        try {
            val messenger = MainActivity.binaryMessenger ?: return
            MethodChannel(messenger, PAYLOAD_CHANNEL).invokeMethod("onNotificationCaptured", message)
        } catch (e: Exception) {
            Log.e(TAG, "forwardToDart error", e)
        }
    }
}

data class Template(
    val pk: String,
    val contains: String,
    val titleBefore: String,
    val titleAfter: String,
    val amountBefore: String,
    val amountAfter: String,
    val ignore: Boolean,
)

package com.budget.tracker_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
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
        private const val KEEPALIVE_CHANNEL_ID = "listener_keepalive_channel"
        private const val KEEPALIVE_NOTIFICATION_ID = 911
        private const val DB_NAME = "db.sqlite"
        private const val OWN_PACKAGE = "com.budget.tracker_app"
        private const val PAYLOAD_EXTRA = "transaction_payload"
        private const val DEDUP_WINDOW_MS = 10 * 60 * 1000L
        private val recentMatches = LinkedHashMap<String, Long>()

        /**
         * 系统是否真的把监听服务绑上了。
         *
         * 不能只看 enabled_notification_listeners：国产 ROM 的省电/后台清理会把服务解绑
         * （甚至强停进程），但「通知使用权」仍然是开启状态，权限检查全部通过、功能却已失效。
         * 这个标记在 onListenerConnected/onListenerDisconnected 里维护；进程被杀后随进程归零，
         * 因此「进程活着但标记为 false」等价于「服务没绑上」。
         */
        @Volatile
        private var listenerConnected = false

        private var rebindHandler: Handler? = null
        private var rebindAttempt = 0
        private var lastRebindRequestAt = 0L
        private var lastForceRebindAt = 0L

        // 解绑后的重试间隔。系统会限制过于频繁的 rebind 请求，所以逐次拉长。
        private val REBIND_DELAYS_MS = longArrayOf(2_000L, 10_000L, 30_000L, 90_000L)
        private const val MIN_REBIND_INTERVAL_MS = 3_000L
        private const val MIN_FORCE_REBIND_INTERVAL_MS = 30_000L

        fun isConnected(): Boolean = listenerConnected

        fun isAccessGranted(context: Context): Boolean {
            return try {
                // Settings.Secure.ENABLED_NOTIFICATION_LISTENERS 是 @hide 常量，公开 SDK 编译不到，使用字符串字面量
                val flat = Settings.Secure.getString(
                    context.contentResolver,
                    "enabled_notification_listeners",
                ) ?: return false
                if (flat.isEmpty()) return false
                // 不同 ROM 的记录格式有差异（完整类名/短类名/仅包名），
                // 应用内只有一个监听服务组件，按包名匹配即可，避免误判导致开关无法保存
                val packageName = context.packageName
                flat.split(":").any {
                    it == packageName || it.startsWith("$packageName/")
                }
            } catch (e: Exception) {
                false
            }
        }

        /**
         * 请求系统重新绑定通知监听服务（API 24+）。
         *
         * NotificationListenerService.requestRebind() 是系统文档指定的解绑恢复手段，也是
         * onListenerDisconnected() 之后唯一允许调用的方法。它只触发重新绑定，不会改动
         * 「通知使用权」，因此不像 setComponentEnabledSetting() 那样在部分 ROM 上丢权限。
         */
        fun requestRebindNow(context: Context): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return false
            val now = SystemClock.elapsedRealtime()
            if (now - lastRebindRequestAt < MIN_REBIND_INTERVAL_MS) return false
            lastRebindRequestAt = now
            return try {
                NotificationListenerService.requestRebind(
                    ComponentName(context, TransactionScannerService::class.java),
                )
                Log.i(TAG, "Requested system to rebind notification listener")
                true
            } catch (t: Throwable) {
                Log.e(TAG, "requestRebind failed", t)
                false
            }
        }

        private fun cancelRebindAttempts() {
            rebindHandler?.removeCallbacksAndMessages(null)
            rebindAttempt = 0
        }

        /**
         * 比 requestRebind 更彻底的一次恢复：先请求系统解绑本应用的服务，再立刻请求重绑。
         * 相当于在 NMS 内部走一遍「解绑 / 重绑」流程（接近用户手动关掉再打开通知使用权），
         * 但不会改动通知使用权本身，因此不会出现「权限被重置、应用内开关却还开着」的情况。
         *
         * 仅在普通 requestRebind 确实没把服务拉回来时作为最后手段调用。
         * requestUnbind(ComponentName) 是 API 34 才有的静态方法。
         */
        fun forceRebindNow(context: Context): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return false
            val now = SystemClock.elapsedRealtime()
            if (now - lastForceRebindAt < MIN_FORCE_REBIND_INTERVAL_MS) return false
            lastForceRebindAt = now
            lastRebindRequestAt = now
            val component = ComponentName(context, TransactionScannerService::class.java)
            return try {
                NotificationListenerService.requestUnbind(component)
                Thread.sleep(500)
                NotificationListenerService.requestRebind(component)
                Log.i(TAG, "Performed unbind/rebind cycle")
                true
            } catch (t: Throwable) {
                Log.e(TAG, "Unbind/rebind cycle failed", t)
                false
            }
        }

        /**
         * 服务被系统解绑后，按退避间隔重试 requestRebind。
         * 只在「权限仍在」时重试；用户主动撤销权限时不应反复重绑。
         */
        private fun scheduleRebind(context: Context) {
            if (!isAccessGranted(context)) return
            val handler = rebindHandler
                ?: Handler(Looper.getMainLooper()).also { rebindHandler = it }
            handler.removeCallbacksAndMessages(null)
            rebindAttempt = 0
            val appContext = context.applicationContext
            val retry = object : Runnable {
                override fun run() {
                    if (listenerConnected) return
                    if (!isAccessGranted(appContext)) return
                    requestRebindNow(appContext)
                    rebindAttempt += 1
                    if (rebindAttempt < REBIND_DELAYS_MS.size) {
                        handler.postDelayed(this, REBIND_DELAYS_MS[rebindAttempt])
                    }
                }
            }
            handler.postDelayed(retry, REBIND_DELAYS_MS[0])
        }
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        listenerConnected = true
        cancelRebindAttempts()
        Log.i(TAG, "Notification listener connected")
        // 以前台服务方式常驻：避免国产 ROM 省电机制冻结/杀死监听服务，
        // 否则后台时「第一个通知正常、随后延迟、最终完全不识别」
        startKeepAliveForeground()
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        listenerConnected = false
        Log.w(TAG, "Notification listener disconnected; scheduling rebind")
        try {
            stopForegroundCompat()
        } catch (e: Exception) {
            Log.e(TAG, "stopForeground error", e)
        }
        // 权限仍在、服务被系统解绑（省电模式/后台清理/强停）时主动拉回来
        scheduleRebind(applicationContext)
    }

    override fun onDestroy() {
        listenerConnected = false
        // 不要在这里取消 rebind 重试：系统解绑后通常紧接着销毁服务，
        // 取消掉就再没人把服务拉回来了。Handler 只持有 applicationContext，不会泄漏 Service。
        super.onDestroy()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        // 过滤自己应用的通知，避免循环监听
        if (sbn.packageName == OWN_PACKAGE) return
        // 监听服务重新绑定后，系统可能重放通知栏里的活动通知，
        // 跳过发布超过 60 秒的旧通知，避免恢复监听时一次性洪泛提示
        val postedAt = sbn.notification?.`when` ?: 0L
        if (postedAt > 0 && System.currentTimeMillis() - postedAt > 60_000L) return
        Thread { handleNotification(applicationContext, sbn) }.start()
    }

    private fun startKeepAliveForeground() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                // 旧版本安装用户可能已存在 IMPORTANCE_MIN 渠道，Android 不允许直接修改已有渠道的重要性，
                // 需要先删除旧渠道再以 IMPORTANCE_NONE 重建，否则升级后常驻通知依然可见
                val existingChannel = nm.getNotificationChannel(KEEPALIVE_CHANNEL_ID)
                if (existingChannel != null && existingChannel.importance != NotificationManager.IMPORTANCE_NONE) {
                    nm.deleteNotificationChannel(KEEPALIVE_CHANNEL_ID)
                }
                // IMPORTANCE_NONE：常驻通知完全不可见（不显示状态栏图标、不出现在通知栏），
                // 但前台服务的保活效果不变。检测提示用的是另一个高优级渠道，不受影响。
                val channel = NotificationChannel(
                    KEEPALIVE_CHANNEL_ID,
                    "交易通知检测",
                    NotificationManager.IMPORTANCE_NONE,
                ).apply {
                    description = "保持交易通知检测服务常驻运行"
                    setShowBadge(false)
                }
                nm.createNotificationChannel(channel)
            }
            val contentIntent = PendingIntent.getActivity(
                this,
                0,
                Intent(this, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(this, KEEPALIVE_CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(this)
            }
            builder.setSmallIcon(R.drawable.notification_icon_android2)
                .setContentTitle("岁计")
                .setContentText("正在检测交易通知")
                .setContentIntent(contentIntent)
                .setOngoing(true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(
                    KEEPALIVE_NOTIFICATION_ID,
                    builder.build(),
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
                )
            } else {
                startForeground(KEEPALIVE_NOTIFICATION_ID, builder.build())
            }
        } catch (e: Exception) {
            Log.e(TAG, "startKeepAliveForeground error", e)
        }
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    private fun handleNotification(context: Context, sbn: StatusBarNotification) {
        try {
            val message = buildMessage(sbn)
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

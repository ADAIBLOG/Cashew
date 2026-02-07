package com.example.budget

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class NotificationListenerForegroundService : Service() {
    private val NOTIFICATION_ID = 101
    private val CHANNEL_ID = "notification_listener_service"
    
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
        // 初始化通知监听
        initializeNotificationListener()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "交易通知监听服务",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Cashew")
            .setContentText("正在监听交易通知")
            .setSmallIcon(R.drawable.notification_icon_android2)
            .build()
    }
    
    private fun initializeNotificationListener() {
        // 初始化通知监听逻辑
        // 这里会通过Flutter侧的notification_listener_service插件实现
    }
}

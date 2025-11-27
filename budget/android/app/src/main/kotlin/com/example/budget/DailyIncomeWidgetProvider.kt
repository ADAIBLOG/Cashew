package com.example.budget

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import io.flutter.plugins.homewidget.HomeWidgetProvider
import io.flutter.plugins.homewidget.HomeWidgetProviderInfo
import io.flutter.plugins.homewidget.HomeWidgetLaunchIntent

class DailyIncomeWidgetProvider : HomeWidgetProvider() {
    override fun getInfo(context: Context): HomeWidgetProviderInfo {
        return HomeWidgetProviderInfo(
            name = "DailyIncomeWidgetProvider",
            defaultHeight = 1,
            defaultWidth = 3,
            minHeight = 1,
            minWidth = 3,
            label = "今日收入组件",
            updatePeriodMillis = 3600000L, // 1 hour
            previewImage = R.drawable.widget_background
        )
    }

    override fun updateWidget(context: Context, appWidgetId: Int, views: RemoteViews, intent: Intent?) {
        val prefs = context.getSharedPreferences("daily_income_widget_prefs", Context.MODE_PRIVATE)
        
        // 设置标题
        views.setTextViewText(R.id.daily_income_title, "今日收入")
        
        // 从SharedPreferences获取数据
        val incomeAmount = prefs.getString("daily_income_amount", "0.00")
        val transactionCount = prefs.getInt("daily_income_transactions", 0)
        
        // 设置金额
        views.setTextViewText(R.id.daily_income_amount, incomeAmount)
        
        // 设置交易数量
        val transactionText = "$transactionCount transactions"
        views.setTextViewText(R.id.daily_income_transactions_number, transactionText)
        
        // 设置背景颜色和透明度
        val backgroundColor = prefs.getString("widget_background_color", "#FFFFFF")
        val backgroundOpacity = prefs.getInt("widget_background_opacity", 255)
        
        if (backgroundColor != null) {
            views.setInt(R.id.widget_background, "setColorFilter", android.graphics.Color.parseColor(backgroundColor))
            views.setInt(R.id.widget_background, "setImageAlpha", backgroundOpacity)
        }
        
        // 设置文本颜色
        val widgetData = prefs.getString("widget_text_color", "#000000")
        if (widgetData != null) {
            val textColor = android.graphics.Color.parseColor(widgetData)
            views.setTextColor(R.id.daily_income_title, textColor)
            views.setTextColor(R.id.daily_income_amount, textColor)
            views.setTextColor(R.id.daily_income_transactions_number, textColor)
        }
        
        // 设置点击事件，与月收入组件相同
        val launchIntent = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("cashew://addTransactionIncomeWidget")
        )
        views.setOnClickPendingIntent(R.id.widget_container, launchIntent)
    }
}

package com.budget.tracker_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class DailyExpenseWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.daily_expense_widget_layout).apply {
                try {
                    // 设置标题
                    setTextViewText(R.id.daily_expense_title, "今日支出")
                    
                    // 从widgetData获取数据
                    val expenseAmount = widgetData.getString("daily_expense_amount", "0.00")
                    val transactionCount = widgetData.getString("daily_expense_transactions", "0")
                    
                    // 设置金额
                    setTextViewText(R.id.daily_expense_amount, expenseAmount)
                    
                    // 设置交易数量
                    setTextViewText(R.id.daily_expense_transactions_number, "$transactionCount transactions")
                    
                    // 设置背景颜色和透明度
                    try {
                        setInt(R.id.widget_background, "setColorFilter", android.graphics.Color.parseColor(
                            widgetData.getString("widgetColorBackground", null) ?: "#FFFFFF"))
                    } catch (e: Exception) {}
                    
                    try {
                        val alpha = widgetData.getString("widgetAlpha", null)?.toIntOrNull() ?: 255
                        setInt(R.id.widget_background, "setImageAlpha", alpha)
                    } catch (e: Exception) {}
                    
                    // 设置文本颜色
                    try {
                        val textColor = widgetData.getString("widgetColorText", null) ?: "#000000"
                        setInt(R.id.daily_expense_title, "setTextColor", android.graphics.Color.parseColor(textColor))
                        setInt(R.id.daily_expense_amount, "setTextColor", android.graphics.Color.parseColor(textColor))
                        setInt(R.id.daily_expense_transactions_number, "setTextColor", android.graphics.Color.parseColor(textColor))
                    } catch (e: Exception) {}
                    
                    // 设置点击事件
                    val pendingIntentWithData = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("addTransactionWidget"))
                    setOnClickPendingIntent(R.id.widget_container, pendingIntentWithData)
                } catch (e: Exception) {}
            }
            
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

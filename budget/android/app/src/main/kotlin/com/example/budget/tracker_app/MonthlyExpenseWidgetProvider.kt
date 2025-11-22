package com.budget.tracker_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import java.util.Calendar
import com.budget.tracker_app.MainActivity
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class MonthlyExpenseWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->

            val views = RemoteViews(context.packageName, R.layout.monthly_expense_widget_layout).apply {
                try {
                  // 获取当前月份的中文名称
                  val calendar = Calendar.getInstance()
                  val monthNames = arrayOf("一月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "十一月", "十二月")
                  val currentMonth = monthNames[calendar.get(Calendar.MONTH)]
                  
                  // 直接设置正确的标题，不依赖任何可能失败的数据
                  setTextViewText(R.id.monthly_expense_title, "${currentMonth}支出")

                  setTextViewText(R.id.monthly_expense_amount, widgetData.getString("monthlyExpenseAmount", null)
                  ?: "0.00")

                  setTextViewText(R.id.monthly_expense_transactions_number, widgetData.getString("monthlyExpenseTransactionsNumber", null)
                  ?: "0 transactions")
                }catch (e: Exception) {
                  // 设置默认标题作为后备
                  setTextViewText(R.id.monthly_expense_title, "本月支出")
                }

                try {
                  setInt(R.id.widget_background, "setColorFilter",  android.graphics.Color.parseColor(widgetData.getString("widgetColorBackground", null)
                  ?: "#FFFFFF"));
                }catch (e: Exception){}

                try {
                  val alpha = Integer.parseInt(widgetData.getString("widgetAlpha", null)?: "255")
                  setInt(R.id.widget_background, "setImageAlpha",  alpha);
                }catch (e: Exception){}

                try {
                  setInt(R.id.monthly_expense_title, "setTextColor",  android.graphics.Color.parseColor(widgetData.getString("widgetColorText", null)
                  ?: "#FFFFFF"))
                  setInt(R.id.monthly_expense_amount, "setTextColor",  android.graphics.Color.parseColor(widgetData.getString("widgetColorText", null)
                  ?: "#FFFFFF"))
                  setInt(R.id.monthly_expense_transactions_number, "setTextColor",  android.graphics.Color.parseColor(widgetData.getString("widgetColorText", null)
                  ?: "#FFFFFF"))
                }catch (e: Exception){}

                try {
                  val pendingIntentWithData = HomeWidgetLaunchIntent.getActivity(
                          context,
                          MainActivity::class.java,
                          Uri.parse("addTransactionWidget"))
                  setOnClickPendingIntent(R.id.widget_container, pendingIntentWithData)
                }catch (e: Exception){}

            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

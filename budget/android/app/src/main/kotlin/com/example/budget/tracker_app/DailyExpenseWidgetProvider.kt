package com.budget.tracker_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import com.budget.tracker_app.MainActivity
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class DailyExpenseWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->

            val views = RemoteViews(context.packageName, R.layout.daily_expense_widget_layout).apply {
                try {
                    // 设置标题为"当日支出"
                    setTextViewText(R.id.daily_expense_title, "当日支出")

                    setTextViewText(R.id.daily_expense_amount, widgetData.getString("dailyExpenseAmount", null)
                    ?: "0.00")

                    setTextViewText(R.id.daily_expense_transactions_number, widgetData.getString("dailyExpenseTransactionsNumber", null)
                    ?: "0 transactions")
                } catch (e: Exception) {
                    // 设置默认标题作为后备
                    setTextViewText(R.id.daily_expense_title, "当日支出")
                }

                try {
                    setInt(R.id.widget_background, "setColorFilter", android.graphics.Color.parseColor(widgetData.getString("widgetColorBackground", null)
                    ?: "#FFFFFF"));
                } catch (e: Exception) {}

                try {
                    val alpha = Integer.parseInt(widgetData.getString("widgetAlpha", null)?: "255")
                    setInt(R.id.widget_background, "setImageAlpha", alpha);
                } catch (e: Exception) {}

                try {
                    setInt(R.id.daily_expense_title, "setTextColor", android.graphics.Color.parseColor(widgetData.getString("widgetColorText", null)
                    ?: "#FFFFFF"))
                    setInt(R.id.daily_expense_amount, "setTextColor", android.graphics.Color.parseColor(widgetData.getString("widgetColorText", null)
                    ?: "#FFFFFF"))
                    setInt(R.id.daily_expense_transactions_number, "setTextColor", android.graphics.Color.parseColor(widgetData.getString("widgetColorText", null)
                    ?: "#FFFFFF"))
                } catch (e: Exception) {}

                try {
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

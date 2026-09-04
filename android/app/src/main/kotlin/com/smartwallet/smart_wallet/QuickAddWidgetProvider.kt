package com.smartwallet.smart_wallet

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class QuickAddWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.quick_add_widget).apply {
                val balance = widgetData.getString("net_balance", "₹0.00") ?: "₹0.00"
                setTextViewText(R.id.widget_net_balance, balance)

                // Open Dashboard
                val dashboardIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("smartwallet://open-dashboard")
                )
                setOnClickPendingIntent(R.id.widget_root, dashboardIntent)

                // Quick Add Expense
                val expenseIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("smartwallet://quick-add?type=expense")
                )
                setOnClickPendingIntent(R.id.btn_quick_expense, expenseIntent)

                // Quick Add Income
                val incomeIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("smartwallet://quick-add?type=income")
                )
                setOnClickPendingIntent(R.id.btn_quick_income, incomeIntent)

                // Quick Add Split
                val splitIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("smartwallet://quick-add?type=split")
                )
                setOnClickPendingIntent(R.id.btn_quick_split, splitIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

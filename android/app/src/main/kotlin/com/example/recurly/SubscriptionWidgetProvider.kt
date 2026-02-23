package com.example.recurly

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class SubscriptionWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        Log.d("SubscriptionWidget", "onUpdate called with ${appWidgetIds.size} widgets")

        appWidgetIds.forEach { widgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.subscription_widget)

                // Get saved data with safe defaults
                val totalSpend = widgetData.getString("total_spend", null) ?: "\$0.00"
                val subscriptionCount = widgetData.getString("subscription_count", null) ?: "0"
                val nextRenewalName = widgetData.getString("next_renewal_name", null) ?: "No subscriptions"
                val nextRenewalDate = widgetData.getString("next_renewal_date", null) ?: ""
                val nextRenewalPrice = widgetData.getString("next_renewal_price", null) ?: ""

                Log.d("SubscriptionWidget", "Data: total=$totalSpend, count=$subscriptionCount")

                // Set text values
                views.setTextViewText(R.id.tv_total_spend, totalSpend)
                views.setTextViewText(R.id.tv_subscription_count, "$subscriptionCount subscriptions")
                views.setTextViewText(R.id.tv_next_name, nextRenewalName)
                views.setTextViewText(R.id.tv_next_date, nextRenewalDate)
                views.setTextViewText(R.id.tv_next_price, nextRenewalPrice)

                appWidgetManager.updateAppWidget(widgetId, views)
                Log.d("SubscriptionWidget", "Widget $widgetId updated successfully")
            } catch (e: Exception) {
                Log.e("SubscriptionWidget", "Failed to update widget $widgetId: ${e.message}")
                e.printStackTrace()
            }
        }
    }
}

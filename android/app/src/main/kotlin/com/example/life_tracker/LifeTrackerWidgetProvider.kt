package com.example.life_tracker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class LifeTrackerWidgetProvider : HomeWidgetProvider() {
    
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.life_tracker_widget).apply {
                // Get data from SharedPreferences
                val streak = widgetData.getInt("streak", 0)
                val weight = widgetData.getString("weight", "--") ?: "--"
                val calories = widgetData.getInt("calories", 0)
                
                // Update TextViews
                setTextViewText(R.id.streak_value, streak.toString())
                setTextViewText(R.id.weight_value, weight)
                setTextViewText(R.id.calories_value, calories.toString())
                
                // Set click action to open app
                val intent = Intent(context, MainActivity::class.java)
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    0,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.widget_container, pendingIntent)
            }
            
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

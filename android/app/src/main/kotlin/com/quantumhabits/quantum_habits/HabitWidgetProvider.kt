package com.quantumhabits.quantum_habits

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.BitmapFactory
import android.view.View
import android.widget.RemoteViews
import java.io.File

/// Home-screen widget: shows the heatmap PNG the Flutter app rendered into
/// HomeWidgetPreferences under "heatmap". Tapping it opens the app.
class HabitWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val prefs = context.getSharedPreferences(
            "HomeWidgetPreferences", Context.MODE_PRIVATE
        )
        val imagePath = prefs.getString("heatmap", null)
        val bitmap = imagePath
            ?.let { path -> File(path).takeIf { it.exists() }?.let { path } }
            ?.let { BitmapFactory.decodeFile(it) }

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.habit_widget)
            if (bitmap != null) {
                views.setImageViewBitmap(R.id.widget_image, bitmap)
                views.setViewVisibility(R.id.widget_empty, View.GONE)
                views.setViewVisibility(R.id.widget_image, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_image, View.GONE)
                views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
            }
            context.packageManager
                .getLaunchIntentForPackage(context.packageName)
                ?.let { launch ->
                    val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                        PendingIntent.FLAG_IMMUTABLE
                    val pi = PendingIntent.getActivity(context, 0, launch, flags)
                    views.setOnClickPendingIntent(R.id.widget_root, pi)
                }
            manager.updateAppWidget(id, views)
        }
    }
}

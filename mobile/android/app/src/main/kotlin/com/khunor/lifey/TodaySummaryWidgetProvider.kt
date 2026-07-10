package com.khunor.lifey

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import org.json.JSONObject

private const val SNAPSHOT_KEY = "today_snapshot"

/**
 * Renders the "today's calories" home screen widget from the snapshot the
 * Flutter app writes via `home_widget` (see widget_snapshot_writer.dart and
 * docs/25-android-widget-ongoing-notification-plan.md). Read-only and
 * silent — tapping anywhere opens the app, there is no other interaction.
 */
class TodaySummaryWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val views = buildRemoteViews(context)
        for (appWidgetId in appWidgetIds) {
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun buildRemoteViews(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_today_summary)
        bindTapIntent(context, views)

        val snapshot = readSnapshot(context)
        if (snapshot == null) {
            renderNoData(views, context.getString(R.string.widget_no_data_fallback))
            return views
        }

        val labels = snapshot.optJSONObject("labels")
        val isToday = snapshot.optString("date") == todayString()
        val calories = if (isToday) snapshot.optInt("calories", 0) else 0
        val calorieGoal = if (snapshot.isNull("calorieGoal")) null else snapshot.optInt("calorieGoal")
        val steps = if (snapshot.isNull("steps")) null else snapshot.optInt("steps")
        val stepGoal = if (snapshot.isNull("stepGoal")) null else snapshot.optInt("stepGoal")

        renderData(
            views = views,
            caloriesLabel = labels?.optString("calories").orEmpty(),
            stepsLabel = labels?.optString("steps").orEmpty(),
            calories = calories,
            calorieGoal = calorieGoal,
            steps = steps,
            stepGoal = stepGoal,
        )
        return views
    }

    private fun bindTapIntent(context: Context, views: RemoteViews) {
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: return
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
    }

    private fun readSnapshot(context: Context): JSONObject? {
        val raw = HomeWidgetPlugin.getData(context).getString(SNAPSHOT_KEY, null) ?: return null
        return try {
            JSONObject(raw)
        } catch (e: org.json.JSONException) {
            null
        }
    }

    private fun todayString(): String {
        // Matches WidgetSnapshotWriter._dayString: zero-padded, device-local
        // calendar day. Locale.US keeps digit formatting locale-independent.
        return SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
    }

    private fun renderNoData(views: RemoteViews, noDataLabel: String) {
        views.setViewVisibility(R.id.widget_content, View.GONE)
        views.setViewVisibility(R.id.widget_no_data, View.VISIBLE)
        views.setTextViewText(R.id.widget_no_data, noDataLabel)
    }

    private fun renderData(
        views: RemoteViews,
        caloriesLabel: String,
        stepsLabel: String,
        calories: Int,
        calorieGoal: Int?,
        steps: Int?,
        stepGoal: Int?,
    ) {
        views.setViewVisibility(R.id.widget_no_data, View.GONE)
        views.setViewVisibility(R.id.widget_content, View.VISIBLE)

        views.setTextViewText(R.id.widget_calories_label, caloriesLabel)
        views.setTextViewText(R.id.widget_calories_value, calories.toString())

        if (calorieGoal != null && calorieGoal > 0) {
            views.setTextViewText(R.id.widget_calories_goal, "/ $calorieGoal")
            views.setViewVisibility(R.id.widget_progress, View.VISIBLE)
            val progress = ((calories.toFloat() / calorieGoal) * 100).toInt().coerceIn(0, 100)
            views.setProgressBar(R.id.widget_progress, 100, progress, false)
        } else {
            views.setTextViewText(R.id.widget_calories_goal, "")
            views.setViewVisibility(R.id.widget_progress, View.GONE)
        }

        if (steps != null) {
            views.setViewVisibility(R.id.widget_steps_row, View.VISIBLE)
            views.setTextViewText(R.id.widget_steps_label, stepsLabel)
            val stepsText = if (stepGoal != null && stepGoal > 0) "$steps / $stepGoal" else steps.toString()
            views.setTextViewText(R.id.widget_steps_value, stepsText)
        } else {
            views.setViewVisibility(R.id.widget_steps_row, View.GONE)
        }
    }
}

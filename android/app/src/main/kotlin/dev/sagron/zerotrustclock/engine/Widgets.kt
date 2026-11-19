package dev.sagron.zerotrustclock.engine

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.text.format.DateFormat
import android.view.View
import android.widget.RemoteViews
import dev.sagron.zerotrustclock.R
import java.util.Date
import java.util.Locale

/**
 * The home screen widgets: Clock and next alarm, World clock, Analog
 * clock. The times are TextClocks, so Android keeps them current; the
 * widgets are drawn again only when the alarms or the cities change.
 *
 * No alarm labels on the home screen: only the day and time.
 */
object Widgets {
    /** Draws every widget of this app again. */
    fun refresh(context: Context) {
        val manager = AppWidgetManager.getInstance(context) ?: return
        fun ids(cls: Class<*>) = try {
            manager.getAppWidgetIds(ComponentName(context, cls))
        } catch (_: Exception) {
            IntArray(0)
        }
        try {
            ids(ClockWidget::class.java).takeIf { it.isNotEmpty() }?.let {
                manager.updateAppWidget(it, clock(context))
            }
            ids(WorldClockWidget::class.java).takeIf { it.isNotEmpty() }?.let {
                manager.updateAppWidget(it, world(context))
            }
            ids(AnalogClockWidget::class.java).takeIf { it.isNotEmpty() }?.let {
                manager.updateAppWidget(it, analog(context))
            }
        } catch (_: Exception) {
            // A widget that can't be drawn now is drawn on the next change.
        }
    }

    private fun locale(context: Context): Locale =
        EnginePrefs.language(context)?.let { Locale.forLanguageTag(it) } ?: Locale.getDefault()

    private fun pattern(context: Context, skeleton: String): String =
        DateFormat.getBestDateTimePattern(locale(context), skeleton)

    private fun open(context: Context, tab: String): PendingIntent = Tabs.open(context, tab)

    /** The time, the date and the next alarm with its button. */
    fun clock(context: Context): RemoteViews {
        val text = Loc.wrap(context)
        val views = RemoteViews(context.packageName, R.layout.widget_clock)
        views.setCharSequence(R.id.widget_time, "setFormat12Hour", pattern(context, "hmm"))
        views.setCharSequence(R.id.widget_time, "setFormat24Hour", pattern(context, "HHmm"))
        val date = pattern(context, "EEEEMMMMd")
        views.setCharSequence(R.id.widget_date, "setFormat12Hour", date)
        views.setCharSequence(R.id.widget_date, "setFormat24Hour", date)
        views.setOnClickPendingIntent(R.id.widget_root, open(context, Tabs.ALARMS))
        views.setOnClickPendingIntent(R.id.widget_add, open(context, "newAlarm"))
        views.setContentDescription(R.id.widget_add, text.getString(R.string.shortcut_new_alarm))

        val next = AlarmStore.load(context)
            .filter { it.enabled && !it.test && it.armedFor != null }
            .minByOrNull { it.armedFor!! }
        if (next == null) {
            views.setTextViewText(R.id.widget_alarm_text, text.getString(R.string.widget_no_alarm))
            views.setViewVisibility(R.id.widget_alarm_button, View.GONE)
        } else {
            val skeleton = if (DateFormat.is24HourFormat(context)) "EEEHHmm" else "EEEhmma"
            views.setTextViewText(
                R.id.widget_alarm_text,
                DateFormat.format(pattern(context, skeleton), Date(next.armedFor!!)),
            )
            if (next.snoozeUntil != null) {
                views.setViewVisibility(R.id.widget_alarm_button, View.GONE)
            } else {
                views.setViewVisibility(R.id.widget_alarm_button, View.VISIBLE)
                views.setTextViewText(
                    R.id.widget_alarm_button,
                    text.getString(if (next.repeats) R.string.upcoming_turn_off_once else R.string.ring_dismiss),
                )
                views.setOnClickPendingIntent(R.id.widget_alarm_button, UpcomingAlarms.buttonIntent(context, next))
            }
        }
        return views
    }

    private val cityRows = intArrayOf(R.id.widget_city_1, R.id.widget_city_2, R.id.widget_city_3, R.id.widget_city_4)
    private val cityNames = intArrayOf(
        R.id.widget_city_name_1,
        R.id.widget_city_name_2,
        R.id.widget_city_name_3,
        R.id.widget_city_name_4,
    )
    private val cityTimes = intArrayOf(
        R.id.widget_city_time_1,
        R.id.widget_city_time_2,
        R.id.widget_city_time_3,
        R.id.widget_city_time_4,
    )

    /** The first four cities of the Clock tab, each with its own live time. */
    fun world(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_world)
        val ids = WorldZones.saved(context).take(cityRows.size)
        val names = WorldZones.names(context, ids)
        views.setViewVisibility(R.id.widget_world_empty, if (ids.isEmpty()) View.VISIBLE else View.GONE)
        val twelve = pattern(context, "hmma")
        val twentyFour = pattern(context, "HHmm")
        for (i in cityRows.indices) {
            val id = ids.getOrNull(i)
            if (id == null) {
                views.setViewVisibility(cityRows[i], View.GONE)
                continue
            }
            views.setViewVisibility(cityRows[i], View.VISIBLE)
            views.setTextViewText(cityNames[i], names[id] ?: id.substringAfterLast('/').replace('_', ' '))
            views.setString(cityTimes[i], "setTimeZone", id)
            views.setCharSequence(cityTimes[i], "setFormat12Hour", twelve)
            views.setCharSequence(cityTimes[i], "setFormat24Hour", twentyFour)
        }
        views.setOnClickPendingIntent(R.id.widget_root, open(context, Tabs.CLOCK))
        return views
    }

    fun analog(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_analog)
        views.setOnClickPendingIntent(R.id.widget_root, open(context, Tabs.ALARMS))
        return views
    }
}

class ClockWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        manager.updateAppWidget(ids, Widgets.clock(context))
    }
}

class WorldClockWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        manager.updateAppWidget(ids, Widgets.world(context))
    }
}

class AnalogClockWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        manager.updateAppWidget(ids, Widgets.analog(context))
    }
}

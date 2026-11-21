package dev.sagron.zerotrustclock.engine

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.os.SystemClock
import android.text.format.DateFormat
import android.view.View
import android.widget.RemoteViews
import dev.sagron.zerotrustclock.R
import dev.sagron.zerotrustclock.engine.core.ClockTimer
import dev.sagron.zerotrustclock.engine.core.TimerMath
import java.util.Date
import java.util.Locale

/**
 * The home screen widgets: Clock and next alarm, World clock, Analog
 * clock, Timer and Stopwatch. The times are TextClocks and Chronometers,
 * so Android keeps them current; the widgets are drawn again only when
 * the alarms, the cities, the timers or the stopwatch change.
 *
 * No alarm or timer labels on the home screen: only times.
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
        refreshTimer(context)
        refreshStopwatch(context)
    }

    /** Draws the Timer widgets again (a timer changed). */
    fun refreshTimer(context: Context) = redraw(context, TimerWidget::class.java) { timer(context) }

    /** Draws the Stopwatch widgets again (the stopwatch changed). */
    fun refreshStopwatch(context: Context) = redraw(context, StopwatchWidget::class.java) { stopwatch(context) }

    private fun redraw(context: Context, cls: Class<*>, views: () -> RemoteViews) {
        try {
            val manager = AppWidgetManager.getInstance(context) ?: return
            val ids = manager.getAppWidgetIds(ComponentName(context, cls))
            if (ids.isNotEmpty()) manager.updateAppWidget(ids, views())
        } catch (_: Exception) {
            // Drawn on the next change.
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

    /** The widget's quick starts, with no timer to show. */
    private val quickStarts = longArrayOf(60, 5 * 60, 10 * 60)

    /**
     * The timer that ends next, counting down, with its buttons. With no
     * timer: three quick starts. The label stays in the app.
     */
    fun timer(context: Context): RemoteViews {
        val text = Loc.wrap(context)
        val views = RemoteViews(context.packageName, R.layout.widget_timer)
        val buttons = intArrayOf(R.id.widget_timer_b1, R.id.widget_timer_b2, R.id.widget_timer_b3)
        views.setTextViewText(R.id.widget_timer_title, text.getString(R.string.widget_timer_title))
        views.setOnClickPendingIntent(R.id.widget_root, open(context, Tabs.TIMERS))
        views.setOnClickPendingIntent(R.id.widget_add, open(context, "newTimer"))
        views.setContentDescription(R.id.widget_add, text.getString(R.string.shortcut_new_timer))

        fun button(i: Int, label: CharSequence?, intent: PendingIntent?) {
            if (label == null || intent == null) {
                views.setViewVisibility(buttons[i], View.GONE)
            } else {
                views.setViewVisibility(buttons[i], View.VISIBLE)
                views.setTextViewText(buttons[i], label)
                views.setOnClickPendingIntent(buttons[i], intent)
            }
        }
        fun still(value: CharSequence?) {
            views.setViewVisibility(R.id.widget_timer_chrono, View.GONE)
            views.setViewVisibility(R.id.widget_timer_text, if (value == null) View.GONE else View.VISIBLE)
            if (value != null) views.setTextViewText(R.id.widget_timer_text, value)
        }
        fun timerButton(t: ClockTimer, label: Int, action: String) =
            text.getString(label) to TimerNotifications.timerPending(context, t, action)

        val now = TimerEngine.now()
        val timers = TimerStore.load(context)
        val t = TimerMath.featured(timers)
        if (t == null) {
            still(null)
            views.setTextViewText(R.id.widget_timer_caption, text.getString(R.string.widget_timer_none))
            for (i in buttons.indices) {
                button(
                    i,
                    TimerNotifications.durationText(quickStarts[i] * 1000),
                    TimerNotifications.timersPending(context, TimerReceiver.ACTION_NEW, quickStarts[i]),
                )
            }
            return views
        }

        // "5:00 timer", and how many more are going.
        val name = TimerNotifications.name(text, t, withLabel = false)
        val more = timers.count { it.id != t.id && (it.running || it.paused || it.ringing) }
        val caption = if (more > 0) text.getString(R.string.widget_timer_more, name, more) else name
        views.setTextViewText(R.id.widget_timer_caption, caption)
        val first: Pair<String, PendingIntent>
        var second: Pair<String, PendingIntent>? = null
        when {
            t.ringing -> {
                still(text.getString(R.string.timer_times_up))
                first = text.getString(R.string.timer_stop) to
                    TimerNotifications.timersPending(context, TimerReceiver.ACTION_STOP_RINGING)
                second = timerButton(t, R.string.timer_add_minute, TimerReceiver.ACTION_ADD_MINUTE)
            }
            t.running -> {
                views.setViewVisibility(R.id.widget_timer_text, View.GONE)
                views.setViewVisibility(R.id.widget_timer_chrono, View.VISIBLE)
                views.setChronometerCountDown(R.id.widget_timer_chrono, true)
                views.setChronometer(
                    R.id.widget_timer_chrono,
                    SystemClock.elapsedRealtime() + (t.endsAt!! - now),
                    null,
                    true,
                )
                first = timerButton(t, R.string.timer_pause, TimerReceiver.ACTION_PAUSE)
                second = timerButton(t, R.string.timer_add_minute, TimerReceiver.ACTION_ADD_MINUTE)
            }
            t.paused -> {
                still(TimerNotifications.durationText(t.left(now)))
                first = timerButton(t, R.string.timer_resume, TimerReceiver.ACTION_START)
                second = timerButton(t, R.string.timer_reset, TimerReceiver.ACTION_RESET)
            }
            else -> {
                still(TimerNotifications.durationText(t.lengthMs))
                first = timerButton(t, R.string.widget_start, TimerReceiver.ACTION_START)
            }
        }
        button(0, first.first, first.second)
        button(1, second?.first, second?.second)
        button(2, null, null)
        return views
    }

    /** The stopwatch, counting, with Start or Pause and Lap or Reset. */
    fun stopwatch(context: Context): RemoteViews {
        val text = Loc.wrap(context)
        val views = RemoteViews(context.packageName, R.layout.widget_stopwatch)
        views.setTextViewText(R.id.widget_stopwatch_title, text.getString(R.string.widget_stopwatch_title))
        views.setOnClickPendingIntent(R.id.widget_root, open(context, Tabs.STOPWATCH))
        val now = TimerEngine.now()
        val s = TimerStore.stopwatch(context)
        fun button(id: Int, label: Int, action: String, code: Int) {
            views.setViewVisibility(id, View.VISIBLE)
            views.setTextViewText(id, text.getString(label))
            views.setOnClickPendingIntent(id, TimerNotifications.stopwatchPending(context, action, code))
        }
        if (s.running) {
            views.setViewVisibility(R.id.widget_stopwatch_text, View.GONE)
            views.setViewVisibility(R.id.widget_stopwatch_chrono, View.VISIBLE)
            views.setChronometer(
                R.id.widget_stopwatch_chrono,
                SystemClock.elapsedRealtime() - s.elapsed(now),
                null,
                true,
            )
            views.setTextViewText(
                R.id.widget_stopwatch_caption,
                if (s.laps.isEmpty()) {
                    text.getString(R.string.timer_running)
                } else {
                    text.getString(R.string.stopwatch_lap, s.laps.size + 1)
                },
            )
            button(
                R.id.widget_stopwatch_b1,
                R.string.timer_pause,
                TimerReceiver.ACTION_STOPWATCH_PAUSE,
                TimerNotifications.CODE_STOPWATCH_PAUSE,
            )
            button(
                R.id.widget_stopwatch_b2,
                R.string.stopwatch_lap_button,
                TimerReceiver.ACTION_STOPWATCH_LAP,
                TimerNotifications.CODE_STOPWATCH_LAP,
            )
        } else {
            views.setViewVisibility(R.id.widget_stopwatch_chrono, View.GONE)
            views.setViewVisibility(R.id.widget_stopwatch_text, View.VISIBLE)
            views.setTextViewText(
                R.id.widget_stopwatch_text,
                TimerNotifications.durationText(s.elapsed(now), roundUp = false),
            )
            views.setTextViewText(
                R.id.widget_stopwatch_caption,
                text.getString(if (s.zero) R.string.tile_tap_to_start else R.string.widget_stopwatch_paused),
            )
            button(
                R.id.widget_stopwatch_b1,
                if (s.zero) R.string.widget_start else R.string.timer_resume,
                TimerReceiver.ACTION_STOPWATCH_START,
                TimerNotifications.CODE_STOPWATCH_START,
            )
            if (s.zero) {
                views.setViewVisibility(R.id.widget_stopwatch_b2, View.GONE)
            } else {
                button(
                    R.id.widget_stopwatch_b2,
                    R.string.timer_reset,
                    TimerReceiver.ACTION_STOPWATCH_RESET,
                    TimerNotifications.CODE_STOPWATCH_RESET,
                )
            }
        }
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

class TimerWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        manager.updateAppWidget(ids, Widgets.timer(context))
    }
}

class StopwatchWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        manager.updateAppWidget(ids, Widgets.stopwatch(context))
    }
}

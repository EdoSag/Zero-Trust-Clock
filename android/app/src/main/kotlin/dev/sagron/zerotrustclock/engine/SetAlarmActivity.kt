package dev.sagron.zerotrustclock.engine

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.provider.AlarmClock
import android.widget.Toast
import dev.sagron.zerotrustclock.R
import java.util.Calendar

/**
 * Android's standard "set an alarm" and "set a timer" requests, from
 * voice assistants and other apps ("set an alarm for 7"). No screen of its own: the alarm is
 * set in the engine at once, and the app opens unless the caller asked to
 * skip it. Callers need the SET_ALARM permission (manifest).
 */
class SetAlarmActivity : Activity() {
    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(Loc.wrap(base))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            handle(intent)
        } catch (_: Exception) {
            open()
        }
        finish()
    }

    private fun handle(intent: Intent) {
        when (intent.action) {
            AlarmClock.ACTION_SET_ALARM -> setAlarm(intent)
            AlarmClock.ACTION_SET_TIMER -> setTimer(intent)
            AlarmClock.ACTION_SHOW_TIMERS -> open(Tabs.TIMERS)
            else -> open()
        }
    }

    private fun setAlarm(intent: Intent) {
        if (!intent.hasExtra(AlarmClock.EXTRA_HOUR)) {
            // No time given: the app, to pick one there.
            open()
            return
        }
        val hour = intent.getIntExtra(AlarmClock.EXTRA_HOUR, 0).coerceIn(0, 23)
        val minute = intent.getIntExtra(AlarmClock.EXTRA_MINUTES, 0).coerceIn(0, 59)
        val days = (intent.getIntegerArrayListExtra(AlarmClock.EXTRA_DAYS) ?: arrayListOf())
            .mapNotNull { isoDay(it) }.toSet()
        val label = intent.getStringExtra(AlarmClock.EXTRA_MESSAGE)?.take(60) ?: ""
        val vibrate = intent.getBooleanExtra(AlarmClock.EXTRA_VIBRATE, true)
        // The same alarm already there: switched on rather than a second one.
        val existing = AlarmStore.load(this).firstOrNull {
            !it.test && it.hour == hour && it.minute == minute && it.days == days
        }
        if (existing != null) {
            if (!existing.enabled) AlarmEngine.setEnabled(this, existing.id, true)
        } else {
            AlarmEngine.save(this, null, hour, minute, days, AlarmEngine.Options(label = label, vibrate = vibrate))
        }
        Toast.makeText(
            this,
            getString(R.string.alarm_set_for, AlarmNotifications.timeText(this, hour, minute)),
            Toast.LENGTH_SHORT,
        ).show()
        if (!intent.getBooleanExtra(AlarmClock.EXTRA_SKIP_UI, false)) open()
    }

    /** "Set a timer for 5 minutes": started at once. */
    private fun setTimer(intent: Intent) {
        val seconds = intent.getIntExtra(AlarmClock.EXTRA_LENGTH, 0)
        if (seconds <= 0) {
            // No length given: the app, to pick one there.
            open(Tabs.TIMERS)
            return
        }
        val label = intent.getStringExtra(AlarmClock.EXTRA_MESSAGE)?.take(60) ?: ""
        TimerEngine.add(this, seconds * 1000L, label, start = true)
        Toast.makeText(
            this,
            getString(R.string.timer_set_for, TimerNotifications.durationText(seconds * 1000L)),
            Toast.LENGTH_SHORT,
        ).show()
        if (!intent.getBooleanExtra(AlarmClock.EXTRA_SKIP_UI, false)) open(Tabs.TIMERS)
    }

    private fun open(tab: String = Tabs.ALARMS) {
        try {
            startActivity(Tabs.intent(this, tab))
        } catch (_: Exception) {
        }
    }

    /** Calendar's SUNDAY = 1 .. SATURDAY = 7, as ISO 1 = Monday .. 7 = Sunday. */
    private fun isoDay(calendarDay: Int): Int? = when (calendarDay) {
        Calendar.SUNDAY -> 7
        in Calendar.MONDAY..Calendar.SATURDAY -> calendarDay - 1
        else -> null
    }
}

package dev.sagron.zerotrustclock.engine

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import dev.sagron.zerotrustclock.engine.core.ClockTimer
import dev.sagron.zerotrustclock.engine.core.Stopwatch
import dev.sagron.zerotrustclock.engine.core.TimerMath
import java.util.UUID

/**
 * Timers and the stopwatch. Like the alarms they live in the engine, not
 * in the app's screens: a timer rings with the app closed, and both keep
 * a notification with their buttons.
 */
object TimerEngine {
    const val ACTION_FIRE = "dev.sagron.zerotrustclock.action.TIMER_FIRE"

    /** Told (on the main thread) when timers or the stopwatch changed, while the app is open. */
    @Volatile
    var onChanged: (() -> Unit)? = null

    fun now(): Long = System.currentTimeMillis()

    fun listJson(context: Context): String = ClockTimer.listToJson(
        TimerStore.load(context).sortedBy { it.createdAt },
    )

    /** A new timer of [lengthMs], started unless [start] is false. Returns its id. */
    fun add(context: Context, lengthMs: Long, label: String, start: Boolean): String {
        val length = lengthMs.coerceIn(1_000L, ClockTimer.MAX_MS)
        val now = now()
        val id = UUID.randomUUID().toString()
        TimerStore.update(context) { list ->
            val t = ClockTimer(
                id = id,
                code = TimerMath.freeCode(list),
                lengthMs = length,
                label = label.trim().take(60),
                createdAt = now,
            )
            list.add(if (start) TimerMath.start(t, now) else t)
        }
        refresh(context)
        return id
    }

    fun start(context: Context, id: String) = change(context, id) { TimerMath.start(it, now()) }

    fun pause(context: Context, id: String) = change(context, id) { TimerMath.pause(it, now()) }

    fun addMinute(context: Context, id: String) = change(context, id) { TimerMath.addMinute(it, now()) }

    fun reset(context: Context, id: String) = change(context, id) { TimerMath.reset(it) }

    fun setLabel(context: Context, id: String, label: String) =
        change(context, id) { it.copy(label = label.trim().take(60)) }

    fun delete(context: Context, id: String) {
        TimerStore.load(context).firstOrNull { it.id == id }?.let { cancel(context, it) }
        TimerStore.update(context) { list -> list.removeAll { it.id == id } }
        TimerNotifications.cancelTimer(context, id)
        refresh(context)
    }

    /** "Stop" on a ringing timer: every ringing timer goes back to its length. */
    fun stopRinging(context: Context) {
        TimerStore.update(context) { list ->
            for (i in list.indices) if (list[i].ringing) list[i] = TimerMath.reset(list[i])
        }
        refresh(context)
    }

    /** "+1:00" on the ringing screen: every ringing timer runs one more minute. */
    fun addMinuteToRinging(context: Context) {
        val now = now()
        TimerStore.update(context) { list ->
            for (i in list.indices) if (list[i].ringing) list[i] = TimerMath.addMinute(list[i], now)
        }
        refresh(context)
    }

    private fun change(context: Context, id: String, how: (ClockTimer) -> ClockTimer) {
        TimerStore.update(context) { list ->
            val i = list.indexOfFirst { it.id == id }
            if (i >= 0) list[i] = how(list[i])
        }
        refresh(context)
    }

    /**
     * Brings Android in line with the timers: rings those whose time has
     * come, sets AlarmManager for the running ones, and shows each
     * timer's notification. Safe to call any time (also after a restart).
     */
    fun refresh(context: Context) {
        val now = now()
        val timers = TimerStore.update(context) { list ->
            for (i in list.indices) {
                if (list[i].running && list[i].endsAt!! <= now) list[i] = TimerMath.ring(list[i])
            }
            list.toList()
        }
        val text = Loc.wrap(context)
        for (t in timers) {
            if (t.running) arm(context, t) else cancel(context, t)
            if (t.running || t.paused) {
                TimerNotifications.showTimer(text, t)
            } else {
                TimerNotifications.cancelTimer(context, t.id)
            }
        }
        if (timers.any { it.ringing }) {
            TimerRingService.update(context)
        } else if (TimerRingService.ringing) {
            TimerRingService.quiet(context)
        }
        notifyChanged()
    }

    /** AlarmManager's call at a timer's end. */
    fun fire(context: Context) = refresh(context)

    fun notifyChanged() {
        val listener = onChanged ?: return
        Handler(Looper.getMainLooper()).post { listener() }
    }

    private fun arm(context: Context, t: ClockTimer) {
        val manager = context.getSystemService(AlarmManager::class.java) ?: return
        val at = t.endsAt ?: return
        val fire = firePendingIntent(context, t)
        try {
            // Exact, and also in Doze. Timers are not alarm clocks, so they
            // don't take the "next alarm" place in the status bar.
            manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, fire)
        } catch (_: SecurityException) {
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, fire)
        }
    }

    private fun cancel(context: Context, t: ClockTimer) {
        context.getSystemService(AlarmManager::class.java)?.cancel(firePendingIntent(context, t))
    }

    private fun firePendingIntent(context: Context, t: ClockTimer): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            TIMER_CODE_BASE + t.code,
            Intent(context, TimerReceiver::class.java)
                .setAction(ACTION_FIRE)
                .setData(Uri.parse("ztclock://timer/${t.id}")),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    // Stopwatch.

    fun stopwatchJson(context: Context): String = TimerStore.stopwatch(context).toJson()

    fun stopwatch(context: Context, how: (Stopwatch, Long) -> Stopwatch) {
        val now = now()
        val s = TimerStore.updateStopwatch(context) { how(it, now) }
        TimerNotifications.showStopwatch(Loc.wrap(context), s, now)
        notifyChanged()
    }

    /** After a restart the notification is gone; show it again. */
    fun refreshStopwatch(context: Context) {
        TimerNotifications.showStopwatch(Loc.wrap(context), TimerStore.stopwatch(context), now())
    }

    private const val TIMER_CODE_BASE = 3_000_000
}

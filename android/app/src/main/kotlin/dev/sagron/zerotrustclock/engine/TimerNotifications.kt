package dev.sagron.zerotrustclock.engine

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import dev.sagron.zerotrustclock.R
import dev.sagron.zerotrustclock.engine.core.ClockTimer
import dev.sagron.zerotrustclock.engine.core.Stopwatch
import java.util.Locale

/**
 * The timers' and the stopwatch's notifications: one per running or
 * paused timer (counting down, with Pause, +1:00 and Reset), the finished
 * timers' notification (which opens "Time's up" over the lock screen),
 * and the stopwatch's.
 *
 * Labels stay off the lock screen: each notification has a public
 * version without them.
 */
object TimerNotifications {
    private const val CHANNEL_TIMERS = "timers"
    const val CHANNEL_TIMER_RINGING = "timer_ringing"
    private const val TIMER_ID = 10
    const val RINGING_ID = 11
    private const val STOPWATCH_ID = 12
    private const val MISSED_ID = 13
    private const val ACCENT = 0xFF6366F1.toInt()

    private fun manager(context: Context): NotificationManager? =
        context.getSystemService(NotificationManager::class.java)

    fun ensureChannels(context: Context) {
        val m = manager(context) ?: return
        val timers = NotificationChannel(
            CHANNEL_TIMERS,
            context.getString(R.string.channel_timers),
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = context.getString(R.string.channel_timers_about)
            setShowBadge(false)
        }
        val ringing = NotificationChannel(
            CHANNEL_TIMER_RINGING,
            context.getString(R.string.channel_timer_ringing),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            // The ring service plays the sound on the alarm volume.
            setSound(null, null)
            enableVibration(false)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setBypassDnd(true)
        }
        m.createNotificationChannels(listOf(timers, ringing))
    }

    /** "4:59", "1:02:03": a time left or counted, in whole seconds. */
    fun durationText(ms: Long, roundUp: Boolean = true): String {
        val total = if (roundUp) (ms.coerceAtLeast(0) + 999) / 1000 else ms.coerceAtLeast(0) / 1000
        val h = total / 3600
        val m = (total % 3600) / 60
        val s = total % 60
        return if (h > 0) {
            String.format(Locale.ROOT, "%d:%02d:%02d", h, m, s)
        } else {
            String.format(Locale.ROOT, "%d:%02d", m, s)
        }
    }

    /** "Pasta", or "5:00 timer" for a timer without a label. */
    fun name(context: Context, t: ClockTimer, withLabel: Boolean): String =
        if (withLabel && t.label.isNotBlank()) t.label else context.getString(R.string.timer_of, durationText(t.lengthMs))

    fun showTimer(context: Context, t: ClockTimer) {
        ensureChannels(context)
        val now = TimerEngine.now()
        fun build(withLabel: Boolean): Notification.Builder {
            val b = Notification.Builder(context, CHANNEL_TIMERS)
                .setSmallIcon(R.drawable.ic_stat_timer)
                .setColor(ACCENT)
                .setContentTitle(name(context, t, withLabel))
                .setCategory(Notification.CATEGORY_STOPWATCH)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setSortKey(String.format(Locale.ROOT, "%020d", t.createdAt))
                .setContentIntent(Tabs.open(context, Tabs.TIMERS))
            if (t.running) {
                b.setUsesChronometer(true)
                    .setChronometerCountDown(true)
                    .setWhen(t.endsAt!!)
                    .setShowWhen(true)
                    .setContentText(context.getString(R.string.timer_running))
            } else {
                b.setShowWhen(false)
                    .setContentText(context.getString(R.string.timer_paused_left, durationText(t.left(now))))
            }
            return b
        }
        val full = build(true)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setPublicVersion(build(false).build())
        if (t.running) {
            full.addAction(timerAction(context, t, R.string.timer_pause, TimerReceiver.ACTION_PAUSE))
            full.addAction(timerAction(context, t, R.string.timer_add_minute, TimerReceiver.ACTION_ADD_MINUTE))
        } else {
            full.addAction(timerAction(context, t, R.string.timer_resume, TimerReceiver.ACTION_START))
        }
        full.addAction(timerAction(context, t, R.string.timer_reset, TimerReceiver.ACTION_RESET))
        notify(context, "timer:${t.id}", TIMER_ID, full.build())
    }

    fun cancelTimer(context: Context, id: String) {
        try {
            manager(context)?.cancel("timer:$id", TIMER_ID)
        } catch (_: Exception) {
        }
    }

    private fun timerAction(context: Context, t: ClockTimer, text: Int, action: String): Notification.Action {
        val pending = PendingIntent.getBroadcast(
            context,
            t.code * 8 + action.hashCode().and(7),
            Intent(context, TimerReceiver::class.java)
                .setAction(action)
                .setData(Uri.parse("ztclock://timer/${t.id}")),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return Notification.Action.Builder(null, context.getString(text), pending).build()
    }

    /**
     * The finished timers' notification: "Time's up", over the lock screen
     * (full screen) or as a heads-up, with +1:00 and Stop.
     */
    fun ringing(context: Context, timers: List<ClockTimer>): Notification {
        ensureChannels(context)
        val open = PendingIntent.getActivity(
            context,
            1,
            Intent(context, TimerRingActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_USER_ACTION),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        fun build(withLabel: Boolean): Notification.Builder = Notification.Builder(context, CHANNEL_TIMER_RINGING)
            .setSmallIcon(R.drawable.ic_stat_timer)
            .setColor(ACCENT)
            .setContentTitle(context.getString(R.string.timer_times_up))
            .setContentText(timers.joinToString(", ") { name(context, it, withLabel) })
            .setCategory(Notification.CATEGORY_ALARM)
            .setOngoing(true)
            .setShowWhen(false)
        val builder = build(true)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setPublicVersion(build(false).build())
            .setAutoCancel(false)
            .setContentIntent(open)
            .setFullScreenIntent(open, true)
            .addAction(ringAction(context, R.string.timer_add_minute, TimerRingService.ACTION_ADD_MINUTE, 21))
            .addAction(ringAction(context, R.string.timer_stop, TimerRingService.ACTION_STOP, 22))
        if (Build.VERSION.SDK_INT >= 31) {
            builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
        }
        return builder.build()
    }

    private fun ringAction(context: Context, text: Int, serviceAction: String, code: Int): Notification.Action {
        val pending = PendingIntent.getService(
            context,
            code,
            Intent(context, TimerRingService::class.java).setAction(serviceAction),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return Notification.Action.Builder(null, context.getString(text), pending).build()
    }

    /** Timers that rang until they stopped by themselves. */
    fun showMissed(context: Context, timers: List<ClockTimer>) {
        if (timers.isEmpty()) return
        ensureChannels(context)
        fun build(withLabel: Boolean): Notification.Builder = Notification.Builder(context, CHANNEL_TIMERS)
            .setSmallIcon(R.drawable.ic_stat_timer)
            .setColor(ACCENT)
            .setContentTitle(context.getString(R.string.timer_missed))
            .setContentText(timers.joinToString(", ") { name(context, it, withLabel) })
        val notification = build(true)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setPublicVersion(build(false).build())
            .setAutoCancel(true)
            .setContentIntent(Tabs.open(context, Tabs.TIMERS))
            .build()
        notify(context, "timer-missed", MISSED_ID, notification)
    }

    /** The stopwatch, while it runs or is paused; gone after Reset. */
    fun showStopwatch(context: Context, s: Stopwatch, now: Long) {
        if (s.zero) {
            try {
                manager(context)?.cancel(STOPWATCH_ID)
            } catch (_: Exception) {
            }
            return
        }
        ensureChannels(context)
        val b = Notification.Builder(context, CHANNEL_TIMERS)
            .setSmallIcon(R.drawable.ic_stat_timer)
            .setColor(ACCENT)
            .setContentTitle(context.getString(R.string.stopwatch))
            .setCategory(Notification.CATEGORY_STOPWATCH)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setContentIntent(Tabs.open(context, Tabs.STOPWATCH))
        if (s.running) {
            b.setUsesChronometer(true)
                .setWhen(now - s.elapsed(now))
                .setShowWhen(true)
            if (s.laps.isNotEmpty()) b.setContentText(context.getString(R.string.stopwatch_lap, s.laps.size + 1))
            b.addAction(stopwatchAction(context, R.string.timer_pause, TimerReceiver.ACTION_STOPWATCH_PAUSE, 31))
            b.addAction(stopwatchAction(context, R.string.stopwatch_lap_button, TimerReceiver.ACTION_STOPWATCH_LAP, 32))
        } else {
            b.setShowWhen(false)
                .setContentText(context.getString(R.string.stopwatch_paused, durationText(s.elapsed(now), roundUp = false)))
            b.addAction(stopwatchAction(context, R.string.timer_resume, TimerReceiver.ACTION_STOPWATCH_START, 33))
            b.addAction(stopwatchAction(context, R.string.timer_reset, TimerReceiver.ACTION_STOPWATCH_RESET, 34))
        }
        notify(context, null, STOPWATCH_ID, b.build())
    }

    private fun stopwatchAction(context: Context, text: Int, action: String, code: Int): Notification.Action {
        val pending = PendingIntent.getBroadcast(
            context,
            code,
            Intent(context, TimerReceiver::class.java).setAction(action),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return Notification.Action.Builder(null, context.getString(text), pending).build()
    }

    private fun notify(context: Context, tag: String?, id: Int, notification: Notification) {
        try {
            manager(context)?.notify(tag, id, notification)
        } catch (_: Exception) {
            // Notifications switched off: the timer itself still rings.
        }
    }
}

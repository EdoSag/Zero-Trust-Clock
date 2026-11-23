package dev.sagron.zerotrustclock.engine

import android.app.Activity
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.text.format.DateFormat
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.TextClock
import android.widget.TextView
import dev.sagron.zerotrustclock.R
import dev.sagron.zerotrustclock.engine.core.Alarm
import dev.sagron.zerotrustclock.engine.core.AlarmSchedule
import dev.sagron.zerotrustclock.engine.core.SunriseMath
import java.time.LocalDate
import java.time.ZonedDateTime
import java.util.Date

/**
 * The sunrise screen: for 15 minutes before the bedtime's wake-up alarm
 * rings, the screen lights up slowly, over the lock screen. It follows
 * the alarm's real next ring, so a morning that is turned off once, paused
 * or a holiday has no sunrise either. Not shown while the phone is in use.
 *
 * Kept in step by [AlarmScheduler.rescheduleAll], like the upcoming alarm.
 */
object Sunrise {
    const val ACTION_START = "dev.sagron.zerotrustclock.action.SUNRISE"
    const val EXTRA_RING_AT = "ringAt"
    private const val CHANNEL = "sunrise"
    private const val NOTIFICATION_ID = 21
    private const val CODE = 3_000_001
    private const val ACCENT = 0xFF6366F1.toInt()
    private const val KEY_FOR = "sunriseFor"

    private fun prefs(context: Context) =
        AlarmStore.deviceContext(context).getSharedPreferences("bedtime", Context.MODE_PRIVATE)

    /** The ring a sunrise was started for (epoch milliseconds), or 0. */
    fun startedFor(context: Context): Long = prefs(context).getLong(KEY_FOR, 0)

    fun refresh(
        context: Context,
        alarms: List<Alarm>,
        now: ZonedDateTime,
        pauseAll: LocalDate?,
        holidays: Set<LocalDate> = emptySet(),
    ) {
        val bedtime = BedtimeEngine.load(context)
        // The wake-up alarm rings with the schedule switched off too, and
        // so does its sunrise.
        val alarm = if (bedtime.sunrise) alarms.firstOrNull { it.id == bedtime.wakeAlarmId } else null
        // Snoozed or ringing: its sunrise is over.
        val ringAt = if (alarm == null || alarm.snoozeUntil != null || alarm.id == RingService.ringingId) {
            null
        } else {
            AlarmSchedule.nextRing(alarm, now, pauseAll, holidays)?.at?.toInstant()?.toEpochMilli()
        }
        val nowMs = now.toInstant().toEpochMilli()
        val startedFor = startedFor(context)
        if (startedFor != 0L && startedFor != ringAt) {
            // The morning it was for is over, or was changed.
            prefs(context).edit().putLong(KEY_FOR, 0).apply()
            end(context)
        }
        if (ringAt == null) {
            cancelStart(context)
            return
        }
        val start = SunriseMath.startFor(ringAt)
        if (nowMs < start) {
            armStart(context, start)
            return
        }
        cancelStart(context)
        // Once for a ring: closed by hand, it stays closed.
        if (startedFor == ringAt) return
        prefs(context).edit().putLong(KEY_FOR, ringAt).apply()
        show(context, ringAt)
    }

    private fun show(context: Context, ringAt: Long) {
        // In use at this hour: already up, or reading in bed.
        if (context.getSystemService(PowerManager::class.java)?.isInteractive == true) return
        val text = Loc.wrap(context)
        val m = context.getSystemService(NotificationManager::class.java) ?: return
        m.createNotificationChannel(
            NotificationChannel(
                CHANNEL,
                text.getString(R.string.channel_sunrise),
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = text.getString(R.string.channel_sunrise_about)
                // Light only: no sound, no vibration.
                setSound(null, null)
                enableVibration(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                // Bedtime's own Do Not Disturb is on at this hour.
                setBypassDnd(true)
            },
        )
        val open = PendingIntent.getActivity(
            context,
            CODE,
            Intent(context, SunriseActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_USER_ACTION)
                .putExtra(EXTRA_RING_AT, ringAt),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val time = DateFormat.getTimeFormat(text).format(Date(ringAt))
        val notification = Notification.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_alarm)
            .setColor(ACCENT)
            .setContentTitle(text.getString(R.string.sunrise_title))
            .setContentText(text.getString(R.string.sunrise_text, time))
            .setCategory(Notification.CATEGORY_ALARM)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setShowWhen(false)
            .setAutoCancel(true)
            .setContentIntent(open)
            // With the screen off this opens the sunrise over the lock screen.
            .setFullScreenIntent(open, true)
            .setTimeoutAfter((ringAt - System.currentTimeMillis()).coerceAtLeast(1_000L))
            .build()
        try {
            m.notify(NOTIFICATION_ID, notification)
        } catch (_: Exception) {
        }
    }

    /** Takes the sunrise's notification away (it ended, or was closed). */
    fun end(context: Context) {
        try {
            context.getSystemService(NotificationManager::class.java)?.cancel(NOTIFICATION_ID)
        } catch (_: Exception) {
        }
    }

    private fun startIntent(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context,
        CODE,
        Intent(context, AlarmReceiver::class.java)
            .setAction(ACTION_START)
            .setData(Uri.parse("ztclock://sunrise/start")),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private fun armStart(context: Context, at: Long) {
        val manager = context.getSystemService(AlarmManager::class.java) ?: return
        try {
            manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, startIntent(context))
        } catch (_: SecurityException) {
            // Exact alarms refused (Android 12): a few minutes late is fine here.
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, startIntent(context))
        }
    }

    private fun cancelStart(context: Context) {
        context.getSystemService(AlarmManager::class.java)?.cancel(startIntent(context))
    }
}

/**
 * The sunrise itself: the time on a sky that goes from dark red to warm
 * white while the screen gets brighter, until the alarm rings. Plain
 * views, over the lock screen.
 */
class SunriseActivity : Activity() {
    private val handler = Handler(Looper.getMainLooper())
    private var ringAt = 0L

    private val tick: Runnable = object : Runnable {
        override fun run() {
            if (!draw()) return
            val near = System.currentTimeMillis() >= ringAt - STEP_MS
            handler.postDelayed(this, if (near) SHORT_STEP_MS else STEP_MS)
        }
    }

    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(Loc.wrap(base))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setShowWhenLocked(true)
        setTurnScreenOn(true)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        setContentView(R.layout.activity_sunrise)
        ringAt = intent?.getLongExtra(Sunrise.EXTRA_RING_AT, 0) ?: 0
        findViewById<View>(R.id.sunrise_close).setOnClickListener {
            Sunrise.end(this)
            finish()
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        ringAt = intent.getLongExtra(Sunrise.EXTRA_RING_AT, ringAt)
    }

    override fun onStart() {
        super.onStart()
        handler.removeCallbacks(tick)
        handler.post(tick)
    }

    override fun onStop() {
        handler.removeCallbacks(tick)
        super.onStop()
    }

    /** Draws the sky as it is now. False when the sunrise is over. */
    private fun draw(): Boolean {
        val now = System.currentTimeMillis()
        if (RingService.ringingId != null) {
            // The alarm rings. This screen kept the phone awake, and on a
            // phone with no screen lock Android then shows a ringing alarm
            // as a banner only: open its screen from here.
            try {
                startActivity(Intent(this, RingActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            } catch (_: Exception) {
            }
            return close()
        }
        // Over: the ring did not come, or this morning's ring was moved
        // or turned off.
        if (ringAt <= 0 || now >= ringAt + WAIT_MS || (now < ringAt && Sunrise.startedFor(this) != ringAt)) {
            return close()
        }
        val p = SunriseMath.progress(now, ringAt)
        val sky = SunriseMath.color(p)
        val ink = if (SunriseMath.lightSky(p)) 0xFF3B1D0A.toInt() else 0xFFFFE9D0.toInt()
        findViewById<View>(R.id.sunrise_root).setBackgroundColor(sky)
        window.statusBarColor = sky
        window.navigationBarColor = sky
        findViewById<TextClock>(R.id.sunrise_clock).setTextColor(ink)
        findViewById<Button>(R.id.sunrise_close).setTextColor(ink)
        findViewById<TextView>(R.id.sunrise_text).apply {
            setTextColor(ink)
            text = getString(
                R.string.sunrise_text,
                DateFormat.getTimeFormat(this@SunriseActivity).format(Date(ringAt)),
            )
        }
        window.attributes = window.attributes.apply { screenBrightness = SunriseMath.brightness(p) }
        return true
    }

    private fun close(): Boolean {
        Sunrise.end(this)
        finish()
        return false
    }

    private companion object {
        const val STEP_MS = 5_000L

        /** Near the ring, to hand over to the ring screen at once. */
        const val SHORT_STEP_MS = 500L

        /** How long after its time the ring is waited for. */
        const val WAIT_MS = 10_000L
    }
}

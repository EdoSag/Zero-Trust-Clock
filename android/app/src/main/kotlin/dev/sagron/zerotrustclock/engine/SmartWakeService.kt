package dev.sagron.zerotrustclock.engine

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.text.format.DateFormat
import dev.sagron.zerotrustclock.R
import dev.sagron.zerotrustclock.engine.core.Alarm
import dev.sagron.zerotrustclock.engine.core.AlarmSchedule
import dev.sagron.zerotrustclock.engine.core.MotionDetector
import java.time.LocalDate
import java.time.ZonedDateTime
import java.util.Date

/**
 * The smart wake window: for the last minutes before an alarm (10, 20 or
 * 30, per alarm), the phone on the bed listens for movement, and rings
 * early when the sleeper stirs, so waking comes in light sleep. Without
 * movement the alarm rings at its time as always: the ring itself is set
 * with AlarmManager as every other one, the window only adds an earlier
 * chance.
 *
 * Kept in step by [AlarmScheduler.rescheduleAll], like the sunrise.
 */
object SmartWakeWindows {
    const val ACTION_OPEN = "dev.sagron.zerotrustclock.action.SMART_WAKE"
    private const val CODE_BASE = 4_000_000

    fun refresh(
        context: Context,
        alarms: List<Alarm>,
        now: ZonedDateTime,
        pauseAll: LocalDate?,
        holidays: Set<LocalDate> = emptySet(),
    ) {
        val nowMs = now.toInstant().toEpochMilli()
        val watch = HashMap<String, Long>()
        for (a in alarms) {
            val window = if (a.id == RingService.ringingId) {
                null
            } else {
                AlarmSchedule.smartWindow(a, now, pauseAll, holidays)
            }
            if (window == null) {
                cancel(context, a)
                continue
            }
            val (opens, ringAt) = window
            if (nowMs < opens) {
                arm(context, a, opens)
            } else {
                cancel(context, a)
                if (nowMs < ringAt) watch[a.id] = ringAt
            }
        }
        SmartWakeService.update(context, watch)
    }

    private fun intent(context: Context, alarm: Alarm): PendingIntent = PendingIntent.getBroadcast(
        context,
        CODE_BASE + alarm.code,
        Intent(context, AlarmReceiver::class.java)
            .setAction(ACTION_OPEN)
            .setData(Uri.parse("ztclock://smart/${alarm.id}")),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private fun arm(context: Context, alarm: Alarm, at: Long) {
        val manager = context.getSystemService(AlarmManager::class.java) ?: return
        try {
            // Exact, in Doze too: it may start the listening service.
            manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, intent(context, alarm))
        } catch (_: SecurityException) {
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, intent(context, alarm))
        }
    }

    fun cancel(context: Context, alarm: Alarm) {
        context.getSystemService(AlarmManager::class.java)?.cancel(intent(context, alarm))
    }
}

/**
 * Listens to the accelerometer during smart wake windows and rings the
 * alarm early on movement (MotionDetector). A foreground service with the
 * phone held awake, for at most half an hour a morning; plain Android, so
 * it also runs before the phone's first unlock.
 */
class SmartWakeService : Service(), SensorEventListener {
    private val handler = Handler(Looper.getMainLooper())
    private var detector = MotionDetector()
    private var sensors: SensorManager? = null
    private var wakeLock: PowerManager.WakeLock? = null

    /** Alarm id to the moment it rings. */
    private var windows: Map<String, Long> = emptyMap()

    private val check: Runnable = object : Runnable {
        override fun run() {
            val now = System.currentTimeMillis()
            windows = windows.filterValues { it > now }
            if (windows.isEmpty() || RingService.ringingId != null) {
                stopNow()
                return
            }
            handler.postDelayed(this, CHECK_MS)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val ids = intent?.getStringArrayExtra(EXTRA_IDS) ?: emptyArray()
        val times = intent?.getLongArrayExtra(EXTRA_TIMES) ?: LongArray(0)
        val next = HashMap<String, Long>()
        for (i in ids.indices) if (i < times.size) next[ids[i]] = times[i]
        try {
            showForeground(next.values.minOrNull())
        } catch (_: Exception) {
        }
        if (next.isEmpty()) {
            stopNow()
            return START_NOT_STICKY
        }
        if (windows.isEmpty()) {
            detector = MotionDetector()
            listen()
        }
        windows = next
        running = next
        holdAwake(next.values.max())
        handler.removeCallbacks(check)
        handler.postDelayed(check, CHECK_MS)
        return START_REDELIVER_INTENT
    }

    private fun showForeground(ringAt: Long?) {
        val text = Loc.wrap(this)
        val m = getSystemService(NotificationManager::class.java)
        m?.createNotificationChannel(
            NotificationChannel(
                CHANNEL,
                text.getString(R.string.channel_smart_wake),
                NotificationManager.IMPORTANCE_MIN,
            ).apply {
                description = text.getString(R.string.channel_smart_wake_about)
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
            },
        )
        val time = if (ringAt == null) "" else DateFormat.getTimeFormat(text).format(Date(ringAt))
        val notification = Notification.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_alarm)
            .setColor(ACCENT)
            .setContentTitle(text.getString(R.string.smart_wake_title))
            .setContentText(text.getString(R.string.smart_wake_text, time))
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setShowWhen(false)
            .build()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun listen() {
        val manager = getSystemService(SensorManager::class.java) ?: return
        val sensor = manager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) ?: return
        sensors = manager
        manager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_NORMAL)
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (windows.isEmpty()) return
        val v = event.values
        if (!detector.add(SystemClock.elapsedRealtime(), v[0], v[1], v[2])) return
        // Stirring: the alarm whose time is nearest rings now.
        val (id, ringAt) = windows.minByOrNull { it.value } ?: return
        windows = emptyMap()
        RingService.ring(this, id, earlyFor = ringAt)
        stopNow()
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private fun holdAwake(until: Long) {
        val power = getSystemService(PowerManager::class.java) ?: return
        val lock = wakeLock ?: power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "ztclock:smartwake").apply {
            setReferenceCounted(false)
        }
        wakeLock = lock
        lock.acquire((until - System.currentTimeMillis()).coerceIn(60_000L, MAX_WINDOW_MS) + 60_000L)
    }

    private fun stopNow() {
        handler.removeCallbacks(check)
        try {
            sensors?.unregisterListener(this)
        } catch (_: Exception) {
        }
        sensors = null
        windows = emptyMap()
        running = emptyMap()
        try {
            if (wakeLock?.isHeld == true) wakeLock?.release()
        } catch (_: Exception) {
        }
        wakeLock = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        handler.removeCallbacks(check)
        try {
            sensors?.unregisterListener(this)
        } catch (_: Exception) {
        }
        try {
            if (wakeLock?.isHeld == true) wakeLock?.release()
        } catch (_: Exception) {
        }
        running = emptyMap()
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL = "smart_wake"
        private const val NOTIFICATION_ID = 23
        private const val ACCENT = 0xFF6366F1.toInt()
        private const val EXTRA_IDS = "ids"
        private const val EXTRA_TIMES = "times"
        private const val CHECK_MS = 30_000L
        private const val MAX_WINDOW_MS = 31 * 60_000L

        /** The windows the running service listens for (empty: not running). */
        @Volatile
        private var running: Map<String, Long> = emptyMap()

        /** Starts, changes or stops listening, to match [watch] (alarm id to ring time). */
        fun update(context: Context, watch: Map<String, Long>) {
            if (watch == running) return
            val intent = Intent(context, SmartWakeService::class.java)
            if (watch.isEmpty()) {
                try {
                    context.stopService(intent)
                } catch (_: Exception) {
                }
                running = emptyMap()
                return
            }
            val ids = watch.keys.toTypedArray()
            intent.putExtra(EXTRA_IDS, ids).putExtra(EXTRA_TIMES, LongArray(ids.size) { watch.getValue(ids[it]) })
            try {
                context.startForegroundService(intent)
                running = watch
            } catch (_: Exception) {
                // Not allowed from here (Android 12+ from the background):
                // the alarm still rings at its time.
            }
        }
    }
}

package dev.sagron.zerotrustclock.engine

import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager

/**
 * Rings finished timers: the app's chime on the alarm volume, vibration,
 * and the "Time's up" notification. One ring for all finished timers.
 */
class TimerRingService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private val ringer by lazy { Ringer(this, handler) }
    private var wakeLock: PowerManager.WakeLock? = null
    private val timeout = Runnable {
        // Nobody answered: stop ringing, leave a note.
        val finished = TimerStore.load(this).filter { it.ringing }
        endRing()
        TimerNotifications.showMissed(Loc.wrap(this), finished)
        TimerEngine.stopRinging(this)
        stopNow()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_UPDATE -> update()
            ACTION_STOP -> {
                endRing()
                TimerEngine.stopRinging(this)
                stopNow()
            }
            ACTION_ADD_MINUTE -> {
                endRing()
                TimerEngine.addMinuteToRinging(this)
                stopNow()
            }
            ACTION_QUIET -> {
                endRing()
                stopNow()
            }
            else -> if (!ringing) stopNow() else update()
        }
        return START_REDELIVER_INTENT
    }

    private fun update() {
        val finished = TimerStore.load(this).filter { it.ringing }
        // First of all: Android gives a started foreground service a few
        // seconds to show its notification.
        try {
            val notification = TimerNotifications.ringing(Loc.wrap(this), finished)
            if (Build.VERSION.SDK_INT >= 34) {
                startForeground(
                    TimerNotifications.RINGING_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED,
                )
            } else {
                startForeground(TimerNotifications.RINGING_ID, notification)
            }
        } catch (_: Exception) {
        }
        if (finished.isEmpty()) {
            endRing()
            stopNow()
            return
        }
        if (ringing) return
        ringing = true
        holdAwake()
        ringer.start(null, gradual = false, vibrate = true)
        handler.removeCallbacks(timeout)
        handler.postDelayed(timeout, RING_MS)
        openScreenIfNotificationCannot()
    }

    /** As for alarms: with the notification blocked, open "Time's up" directly. */
    private fun openScreenIfNotificationCannot() {
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val canShow = manager.areNotificationsEnabled() &&
            (Build.VERSION.SDK_INT < 34 || manager.canUseFullScreenIntent())
        if (canShow) return
        try {
            startActivity(Intent(this, TimerRingActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (_: Exception) {
        }
    }

    private fun endRing() {
        handler.removeCallbacks(timeout)
        ringer.stop()
        if (ringing) {
            ringing = false
            onEnded?.let { listener -> handler.post { listener() } }
        }
    }

    private fun holdAwake() {
        if (wakeLock?.isHeld == true) return
        val power = getSystemService(PowerManager::class.java) ?: return
        wakeLock = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "ztclock:timer").apply {
            setReferenceCounted(false)
            acquire(RING_MS + 60_000L)
        }
    }

    private fun stopNow() {
        try {
            if (wakeLock?.isHeld == true) wakeLock?.release()
        } catch (_: Exception) {
        }
        wakeLock = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        endRing()
        try {
            if (wakeLock?.isHeld == true) wakeLock?.release()
        } catch (_: Exception) {
        }
        super.onDestroy()
    }

    companion object {
        const val ACTION_UPDATE = "dev.sagron.zerotrustclock.action.TIMER_RING_UPDATE"
        const val ACTION_STOP = "dev.sagron.zerotrustclock.action.TIMER_RING_STOP"
        const val ACTION_ADD_MINUTE = "dev.sagron.zerotrustclock.action.TIMER_RING_ADD_MINUTE"
        const val ACTION_QUIET = "dev.sagron.zerotrustclock.action.TIMER_RING_QUIET"

        /** An unanswered timer rings this long, then stops by itself. */
        const val RING_MS = 10 * 60_000L

        /** True while finished timers ring. */
        @Volatile
        var ringing = false
            private set

        /** Told (on the main thread) when the ring ends, so "Time's up" closes. */
        @Volatile
        var onEnded: (() -> Unit)? = null

        /** Starts ringing, or shows the finished timers again. */
        fun update(context: Context) {
            val intent = Intent(context, TimerRingService::class.java).setAction(ACTION_UPDATE)
            try {
                if (ringing) context.startService(intent) else context.startForegroundService(intent)
            } catch (_: Exception) {
                // Android refused to start it in the background: at least say so.
                TimerNotifications.showMissed(Loc.wrap(context), TimerStore.load(context).filter { it.ringing })
            }
        }

        /** No timer is finished any more (stopped in the app). */
        fun quiet(context: Context) = send(context, ACTION_QUIET)

        fun send(context: Context, action: String) {
            try {
                context.startService(Intent(context, TimerRingService::class.java).setAction(action))
            } catch (_: Exception) {
            }
        }
    }
}

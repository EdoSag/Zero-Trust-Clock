package dev.sagron.zerotrustclock.engine

import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import dev.sagron.zerotrustclock.R
import dev.sagron.zerotrustclock.engine.core.Alarm
import dev.sagron.zerotrustclock.engine.core.AlarmSchedule

/**
 * Rings an alarm: sound on the alarm volume, vibration, and the
 * notification that opens the ring screen. Plain Android, no Flutter, so
 * it also runs before the phone's first unlock.
 */
class RingService : Service() {
    private enum class Outcome { DISMISS, SNOOZE, TIMEOUT }

    private val handler = Handler(Looper.getMainLooper())
    private val timeout = Runnable { end(Outcome.TIMEOUT) }
    private var player: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var focus: AudioFocusRequest? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_RING -> ring(intent.getStringExtra(EXTRA_ID))
            ACTION_SNOOZE -> end(Outcome.SNOOZE)
            ACTION_DISMISS -> end(Outcome.DISMISS)
            else -> if (ringingId == null) stopNow()
        }
        // If Android has to restart the service mid-ring, it rings again.
        return START_REDELIVER_INTENT
    }

    private fun ring(id: String?) {
        val text = Loc.wrap(this)
        val alarm = if (id == null) null else AlarmStore.load(this).firstOrNull { it.id == id }
        // First of all: Android gives a started foreground service a few
        // seconds to show its notification.
        try {
            showForeground(text, alarm)
        } catch (_: Exception) {
            // Keep going: a ring without its notification beats no ring.
        }
        if (alarm == null) {
            if (ringingId == null) stopNow()
            return
        }
        if (ringingId == alarm.id) return // Already ringing.
        // Another alarm was still ringing: it ends, this one takes over.
        ringingId?.let { finishInStore(it, Outcome.DISMISS) }
        ringingId = alarm.id
        AlarmStore.update(this) { list ->
            val i = list.indexOfFirst { it.id == alarm.id }
            if (i >= 0) {
                list[i] = list[i].copy(armedFor = null, snoozeUntil = null)
            }
        }
        AlarmNotifications.cancelSnoozed(this, alarm.id)
        holdAwake()
        stopSound()
        startSound()
        stopVibration()
        if (alarm.vibrate) startVibration()
        handler.removeCallbacks(timeout)
        handler.postDelayed(timeout, RING_FOR_MS)
        openRingScreenIfNotificationCannot()
        // Sets a repeating alarm's next day, and tells the open app.
        AlarmScheduler.rescheduleAll(this)
    }

    /**
     * With notifications or the full-screen permission switched off, the
     * notification can't open the ring screen. Try to open it directly;
     * Android allows that while the app is on screen. The Alarm check
     * screen tells the user to switch them back on.
     */
    private fun openRingScreenIfNotificationCannot() {
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val canShow = manager.areNotificationsEnabled() &&
            (Build.VERSION.SDK_INT < 34 || manager.canUseFullScreenIntent())
        if (canShow) return
        try {
            startActivity(
                Intent(this, RingActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        } catch (_: Exception) {
        }
    }

    private fun showForeground(text: Context, alarm: Alarm?) {
        val notification = AlarmNotifications.ringing(text, alarm)
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(
                AlarmNotifications.RINGING_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED,
            )
        } else {
            startForeground(AlarmNotifications.RINGING_ID, notification)
        }
    }

    private fun end(outcome: Outcome) {
        val id = ringingId
        if (id == null) {
            stopNow()
            return
        }
        handler.removeCallbacks(timeout)
        stopSound()
        stopVibration()
        ringingId = null
        val before = finishInStore(id, outcome)
        val text = Loc.wrap(this)
        if (outcome == Outcome.TIMEOUT && before != null) AlarmNotifications.showMissed(text, before)
        if (outcome == Outcome.SNOOZE) {
            AlarmStore.load(this).firstOrNull { it.id == id }?.let { AlarmNotifications.showSnoozed(text, it) }
        }
        AlarmScheduler.rescheduleAll(this)
        onEnded?.let { listener -> handler.post { listener() } }
        stopNow()
    }

    /** Writes what the ring's end means for the alarm. Returns it as it was. */
    private fun finishInStore(id: String, outcome: Outcome): Alarm? {
        val now = AlarmEngine.now()
        return AlarmStore.update(this) { list ->
            val i = list.indexOfFirst { it.id == id }
            if (i < 0) {
                null
            } else {
                val a = list[i]
                when {
                    outcome == Outcome.SNOOZE -> list[i] = AlarmSchedule.snooze(a, now)
                    a.test -> list.removeAt(i)
                    else -> list[i] = AlarmSchedule.afterRing(a, now)
                }
                a
            }
        }
    }

    private fun startSound() {
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val audio = getSystemService(AudioManager::class.java)
        try {
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(attributes)
                .build()
            audio?.requestAudioFocus(request)
            focus = request
        } catch (_: Exception) {
        }
        // The sound inside the app first: it is always there, also before
        // the first unlock. The phone's own alarm sound is the fallback.
        player = try {
            MediaPlayer().apply {
                setAudioAttributes(attributes)
                resources.openRawResourceFd(R.raw.alarm_default).use { fd ->
                    setDataSource(fd.fileDescriptor, fd.startOffset, fd.length)
                }
                isLooping = true
                prepare()
                start()
            }
        } catch (_: Exception) {
            try {
                MediaPlayer().apply {
                    setAudioAttributes(attributes)
                    setDataSource(
                        this@RingService,
                        RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM),
                    )
                    isLooping = true
                    prepare()
                    start()
                }
            } catch (_: Exception) {
                null
            }
        }
    }

    private fun stopSound() {
        try {
            player?.stop()
        } catch (_: Exception) {
        }
        try {
            player?.release()
        } catch (_: Exception) {
        }
        player = null
        try {
            focus?.let { getSystemService(AudioManager::class.java)?.abandonAudioFocusRequest(it) }
        } catch (_: Exception) {
        }
        focus = null
    }

    private fun startVibration() {
        val v = getSystemService(Vibrator::class.java) ?: return
        val effect = VibrationEffect.createWaveform(longArrayOf(0, 600, 500), 0)
        try {
            if (Build.VERSION.SDK_INT >= 33) {
                v.vibrate(effect, VibrationAttributes.createForUsage(VibrationAttributes.USAGE_ALARM))
            } else {
                @Suppress("DEPRECATION")
                v.vibrate(
                    effect,
                    AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).build(),
                )
            }
            vibrator = v
        } catch (_: Exception) {
        }
    }

    private fun stopVibration() {
        try {
            vibrator?.cancel()
        } catch (_: Exception) {
        }
        vibrator = null
    }

    private fun holdAwake() {
        if (wakeLock?.isHeld == true) return
        val power = getSystemService(PowerManager::class.java) ?: return
        wakeLock = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "ztclock:ring").apply {
            setReferenceCounted(false)
            acquire(RING_FOR_MS + 60_000L)
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
        handler.removeCallbacks(timeout)
        stopSound()
        stopVibration()
        try {
            if (wakeLock?.isHeld == true) wakeLock?.release()
        } catch (_: Exception) {
        }
        super.onDestroy()
    }

    companion object {
        const val ACTION_RING = "dev.sagron.zerotrustclock.action.RING"
        const val ACTION_SNOOZE = "dev.sagron.zerotrustclock.action.SNOOZE"
        const val ACTION_DISMISS = "dev.sagron.zerotrustclock.action.DISMISS"
        const val EXTRA_ID = "id"

        /** An unanswered alarm stops by itself after this long. */
        const val RING_FOR_MS = 10 * 60_000L

        /** The alarm ringing right now, if any. */
        @Volatile
        var ringingId: String? = null
            private set

        /** Told (on the main thread) when a ring ends, so the ring screen closes. */
        @Volatile
        var onEnded: (() -> Unit)? = null

        fun ring(context: Context, id: String) {
            val intent = Intent(context, RingService::class.java).setAction(ACTION_RING).putExtra(EXTRA_ID, id)
            try {
                context.startForegroundService(intent)
            } catch (_: Exception) {
                // Android refused to start the service (only possible when
                // exact alarms are switched off on Android 12): say so.
                AlarmStore.load(context).firstOrNull { it.id == id }?.let {
                    AlarmNotifications.showMissed(Loc.wrap(context), it)
                }
                AlarmScheduler.rescheduleAll(context)
            }
        }

        fun send(context: Context, action: String) {
            try {
                context.startService(Intent(context, RingService::class.java).setAction(action))
            } catch (_: Exception) {
            }
        }
    }
}

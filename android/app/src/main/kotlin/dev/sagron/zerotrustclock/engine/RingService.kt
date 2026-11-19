package dev.sagron.zerotrustclock.engine

import android.app.NotificationManager
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
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
    private var watchingLock = false

    /**
     * A label must not stay on the lock screen when the phone is locked
     * while its alarm rings. Screen off: the label goes from the
     * notification at once. Screen on or unlocked: it shows again if the
     * phone really is unlocked.
     */
    private val lockWatcher = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            refreshNotification(hideLabel = intent.action == Intent.ACTION_SCREEN_OFF)
        }
    }

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
        watchLock()
        holdAwake()
        stopSound()
        startSound(alarm)
        stopVibration()
        if (alarm.vibrate) startVibration()
        handler.removeCallbacks(timeout)
        handler.postDelayed(timeout, alarm.ringMinutes * 60_000L)
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

    private fun watchLock() {
        if (watchingLock) return
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        try {
            if (Build.VERSION.SDK_INT >= 33) {
                registerReceiver(lockWatcher, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(lockWatcher, filter)
            }
            watchingLock = true
        } catch (_: Exception) {
        }
    }

    private fun unwatchLock() {
        if (!watchingLock) return
        watchingLock = false
        try {
            unregisterReceiver(lockWatcher)
        } catch (_: Exception) {
        }
    }

    /** Shows the ringing notification again, with or without the label. */
    private fun refreshNotification(hideLabel: Boolean) {
        val id = ringingId ?: return
        val alarm = AlarmStore.load(this).firstOrNull { it.id == id } ?: return
        try {
            getSystemService(NotificationManager::class.java)?.notify(
                AlarmNotifications.RINGING_ID,
                AlarmNotifications.ringing(Loc.wrap(this), alarm, hideLabel = hideLabel, update = true),
            )
        } catch (_: Exception) {
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

    private fun startSound(alarm: Alarm?) {
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
        // The alarm's own sound, then the app's chime (always there, also
        // before the first unlock), then the phone's alarm sound.
        val p = Sounds.player(this, alarm?.sound, attributes)
            ?: Sounds.player(this, null, attributes)
            ?: Sounds.player(this, Sounds.SYSTEM, attributes)
        player = p
        try {
            if (alarm?.gradual == true) {
                volume = GRADUAL_START
                p?.setVolume(volume, volume)
                handler.postDelayed(louder, 1_000L)
            }
            p?.start()
        } catch (_: Exception) {
        }
    }

    /** "Gradually louder": from quiet to full over a minute. */
    private var volume = 1f
    private val louder: Runnable = object : Runnable {
        override fun run() {
            val p = player ?: return
            volume = (volume + (1f - GRADUAL_START) / 60f).coerceAtMost(1f)
            try {
                p.setVolume(volume, volume)
            } catch (_: Exception) {
            }
            if (volume < 1f) handler.postDelayed(this, 1_000L)
        }
    }

    private fun stopSound() {
        handler.removeCallbacks(louder)
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
            acquire(MAX_RING_MS + 60_000L)
        }
    }

    private fun stopNow() {
        unwatchLock()
        try {
            if (wakeLock?.isHeld == true) wakeLock?.release()
        } catch (_: Exception) {
        }
        wakeLock = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        unwatchLock()
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

        /** The longest an unanswered alarm rings ("Silence after" at most an hour). */
        const val MAX_RING_MS = 60 * 60_000L
        private const val GRADUAL_START = 0.05f

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

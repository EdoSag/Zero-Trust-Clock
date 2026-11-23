package dev.sagron.zerotrustclock.engine

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import dev.sagron.zerotrustclock.engine.core.RingVolume

/**
 * Plays a ring on the alarm volume and vibrates, for alarms and timers.
 * Never silent: a sound that can't play falls back to the app's chime,
 * then to the phone's alarm sound.
 */
class Ringer(private val context: Context, private val handler: Handler) {
    private var player: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var focus: AudioFocusRequest? = null
    private var volume = 1f

    /** The alarm volume before this ring raised it, and what it raised it to. */
    private var volumeBefore: Int? = null
    private var volumeRaisedTo = 0

    /**
     * [minVolumePercent]: "ring at least this loud". A lower alarm volume
     * is raised for this ring and put back when it ends.
     */
    fun start(sound: String?, gradual: Boolean, vibrate: Boolean, minVolumePercent: Int = 0) {
        stop()
        raiseVolume(minVolumePercent)
        startSound(sound, gradual)
        if (vibrate) startVibration()
    }

    fun stop() {
        stopSound()
        stopVibration()
        restoreVolume()
    }

    private fun raiseVolume(percent: Int) {
        if (percent <= 0) return
        try {
            val audio = context.getSystemService(AudioManager::class.java) ?: return
            val current = audio.getStreamVolume(AudioManager.STREAM_ALARM)
            val want = RingVolume.atLeast(
                current,
                audio.getStreamMaxVolume(AudioManager.STREAM_ALARM),
                percent,
            )
            if (want <= current) return
            audio.setStreamVolume(AudioManager.STREAM_ALARM, want, 0)
            volumeBefore = current
            volumeRaisedTo = want
        } catch (_: Exception) {
            // Not allowed to change it (a Do Not Disturb mode): rings as it is.
        }
    }

    /** Back to the volume before the ring, unless it was changed by hand meanwhile. */
    private fun restoreVolume() {
        val before = volumeBefore ?: return
        volumeBefore = null
        try {
            val audio = context.getSystemService(AudioManager::class.java) ?: return
            if (audio.getStreamVolume(AudioManager.STREAM_ALARM) == volumeRaisedTo) {
                audio.setStreamVolume(AudioManager.STREAM_ALARM, before, 0)
            }
        } catch (_: Exception) {
        }
    }

    private fun startSound(sound: String?, gradual: Boolean) {
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val audio = context.getSystemService(AudioManager::class.java)
        try {
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(attributes)
                .build()
            audio?.requestAudioFocus(request)
            focus = request
        } catch (_: Exception) {
        }
        // The chosen sound, then the app's chime (always there, also
        // before the first unlock), then the phone's alarm sound.
        val p = Sounds.player(context, sound, attributes)
            ?: Sounds.player(context, null, attributes)
            ?: Sounds.player(context, Sounds.SYSTEM, attributes)
        player = p
        try {
            if (gradual) {
                volume = GRADUAL_START
                p?.setVolume(volume, volume)
                handler.postDelayed(louder, 1_000L)
            }
            p?.start()
        } catch (_: Exception) {
        }
    }

    /** "Gradually louder": from quiet to full over a minute. */
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
            focus?.let { context.getSystemService(AudioManager::class.java)?.abandonAudioFocusRequest(it) }
        } catch (_: Exception) {
        }
        focus = null
    }

    private fun startVibration() {
        val v = context.getSystemService(Vibrator::class.java) ?: return
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

    private companion object {
        const val GRADUAL_START = 0.05f
    }
}

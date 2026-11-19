package dev.sagron.zerotrustclock.engine

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Build
import android.os.IBinder
import dev.sagron.zerotrustclock.R
import kotlin.random.Random

/**
 * Sleep sounds: white, pink or deep (brown) noise, made on the phone (no
 * sound files), on the media volume, stopping by itself after the sleep
 * timer with a fade.
 */
class SleepSoundService : Service() {
    /** Each play gets a number; a sound thread stops once it is not the latest. */
    @Volatile
    private var generation = 0

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PLAY -> {
                val kind = intent.getStringExtra(EXTRA_KIND) ?: WHITE
                val minutes = intent.getIntExtra(EXTRA_MINUTES, 30).coerceIn(1, 600)
                play(kind, minutes)
            }
            else -> stop()
        }
        return START_NOT_STICKY
    }

    private fun play(kind: String, minutes: Int) {
        val endsAt = System.currentTimeMillis() + minutes * 60_000L
        try {
            val notification = notification(kind, endsAt)
            if (Build.VERSION.SDK_INT >= 29) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (_: Exception) {
            stopSelf()
            return
        }
        val gen = ++generation
        state = State(kind, endsAt)
        TimerEngine.notifyChanged()
        Thread { generate(kind, endsAt, gen) }.apply {
            name = "sleep-sounds"
            start()
        }
    }

    private fun stop() {
        generation++
        state = null
        TimerEngine.notifyChanged()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        generation++
        state = null
        super.onDestroy()
    }

    /** Writes noise to an AudioTrack until stopped or the timer ends (last 30 s fade out). */
    private fun generate(kind: String, endsAt: Long, gen: Int) {
        val rate = 44_100
        val size = AudioTrack.getMinBufferSize(rate, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT)
            .coerceAtLeast(rate / 5 * 2)
        val track = try {
            AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build(),
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setSampleRate(rate)
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build(),
                )
                .setBufferSizeInBytes(size)
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build()
        } catch (_: Exception) {
            return
        }
        val noise = Noise(kind)
        val buffer = ShortArray(rate / 10)
        try {
            track.play()
            // A gentle start over 5 seconds.
            var fadeIn = 0f
            while (generation == gen) {
                val left = endsAt - System.currentTimeMillis()
                if (left <= 0) break
                val fadeOut = (left / FADE_MS.toFloat()).coerceAtMost(1f)
                fadeIn = (fadeIn + 0.02f).coerceAtMost(1f)
                val gain = VOLUME * fadeIn * fadeOut
                for (i in buffer.indices) {
                    buffer[i] = (noise.next() * gain * Short.MAX_VALUE).toInt().coerceIn(-32767, 32767).toShort()
                }
                track.write(buffer, 0, buffer.size)
            }
        } catch (_: Exception) {
        } finally {
            try {
                track.stop()
            } catch (_: Exception) {
            }
            track.release()
        }
        if (generation == gen) {
            // The sleep timer ran out.
            generation++
            state = null
            TimerEngine.notifyChanged()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
    }

    private fun notification(kind: String, endsAt: Long): Notification {
        val text = Loc.wrap(this)
        val m = getSystemService(NotificationManager::class.java)
        m?.createNotificationChannel(
            NotificationChannel(CHANNEL, text.getString(R.string.channel_sleep_sounds), NotificationManager.IMPORTANCE_LOW),
        )
        val stop = PendingIntent.getService(
            this,
            1,
            Intent(this, SleepSoundService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return Notification.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_alarm)
            .setColor(0xFF6366F1.toInt())
            .setContentTitle(text.getString(R.string.sleep_sounds_playing, name(text, kind)))
            .setUsesChronometer(true)
            .setChronometerCountDown(true)
            .setWhen(endsAt)
            .setShowWhen(true)
            .setOngoing(true)
            .setContentIntent(Tabs.open(this, Tabs.BEDTIME))
            .addAction(Notification.Action.Builder(null, text.getString(R.string.timer_stop), stop).build())
            .build()
    }

    private fun name(context: Context, kind: String): String = context.getString(
        when (kind) {
            PINK -> R.string.sleep_sound_pink
            BROWN -> R.string.sleep_sound_brown
            else -> R.string.sleep_sound_white
        },
    )

    /** White noise, or filtered to pink (Paul Kellet's filter) or brown. */
    private class Noise(private val kind: String) {
        private val random = Random(System.nanoTime())
        private var b0 = 0f
        private var b1 = 0f
        private var b2 = 0f
        private var b3 = 0f
        private var b4 = 0f
        private var b5 = 0f
        private var b6 = 0f
        private var brown = 0f

        fun next(): Float {
            val white = random.nextFloat() * 2f - 1f
            return when (kind) {
                PINK -> {
                    b0 = 0.99886f * b0 + white * 0.0555179f
                    b1 = 0.99332f * b1 + white * 0.0750759f
                    b2 = 0.96900f * b2 + white * 0.1538520f
                    b3 = 0.86650f * b3 + white * 0.3104856f
                    b4 = 0.55000f * b4 + white * 0.5329522f
                    b5 = -0.7616f * b5 - white * 0.0168980f
                    val pink = b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362f
                    b6 = white * 0.115926f
                    pink * 0.11f
                }
                BROWN -> {
                    brown = (brown + 0.02f * white) / 1.02f
                    brown * 3.5f
                }
                else -> white * 0.5f
            }
        }
    }

    data class State(val kind: String, val endsAt: Long)

    companion object {
        const val ACTION_PLAY = "dev.sagron.zerotrustclock.action.SLEEP_PLAY"
        const val ACTION_STOP = "dev.sagron.zerotrustclock.action.SLEEP_STOP"
        const val EXTRA_KIND = "kind"
        const val EXTRA_MINUTES = "minutes"
        const val WHITE = "white"
        const val PINK = "pink"
        const val BROWN = "brown"
        private const val CHANNEL = "sleep_sounds"
        private const val NOTIFICATION_ID = 21
        private const val FADE_MS = 30_000L
        private const val VOLUME = 0.6f

        /** What plays now, or null. */
        @Volatile
        var state: State? = null
            private set

        fun play(context: Context, kind: String, minutes: Int) {
            context.startForegroundService(
                Intent(context, SleepSoundService::class.java)
                    .setAction(ACTION_PLAY)
                    .putExtra(EXTRA_KIND, kind)
                    .putExtra(EXTRA_MINUTES, minutes),
            )
        }

        fun stop(context: Context) {
            if (state == null) return
            try {
                context.startService(Intent(context, SleepSoundService::class.java).setAction(ACTION_STOP))
            } catch (_: Exception) {
            }
        }
    }
}

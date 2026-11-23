package dev.sagron.zerotrustclock.engine

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.provider.OpenableColumns
import dev.sagron.zerotrustclock.R
import java.io.File
import java.util.UUID

/**
 * Alarm sounds. A sound picked from the phone (a ringtone or any audio
 * file) is copied into the app's device-protected storage, so it plays
 * before the phone's first unlock too. Whatever goes wrong, an alarm
 * falls back to the app's own chime, never to silence.
 */
object Sounds {
    private const val DIR = "sounds"
    private const val MAX_BYTES = 20L * 1024 * 1024
    const val SYSTEM = "system"
    private const val FILE = "file:"
    private const val URI = "uri:"
    private const val BUILT_IN = "builtin:"

    /** The app's other sounds, by the name after "builtin:". */
    private val builtIn = mapOf(
        "bells" to R.raw.alarm_bells,
        "beeps" to R.raw.alarm_beeps,
        "sunrise" to R.raw.alarm_sunrise,
        "buzzer" to R.raw.alarm_buzzer,
    )

    private fun dir(context: Context): File =
        File(AlarmStore.deviceContext(context).filesDir, DIR).apply { mkdirs() }

    /** A copy of [uri] in the app, as a sound value, or null when it can't be read. */
    fun copyIn(context: Context, uri: Uri): String? {
        val ext = displayName(context, uri)?.substringAfterLast('.', "")
            ?.takeIf { it.length in 1..5 && it.all(Char::isLetterOrDigit) } ?: "audio"
        val target = File(dir(context), "${UUID.randomUUID()}.$ext")
        return try {
            val input = context.contentResolver.openInputStream(uri) ?: return null
            input.use { inp ->
                target.outputStream().use { out ->
                    val buf = ByteArray(64 * 1024)
                    var total = 0L
                    while (true) {
                        val n = inp.read(buf)
                        if (n < 0) break
                        total += n
                        if (total > MAX_BYTES) throw IllegalStateException("too large")
                        out.write(buf, 0, n)
                    }
                }
            }
            FILE + target.name
        } catch (_: Exception) {
            target.delete()
            null
        }
    }

    /** A sound the phone can only play once unlocked (the copy failed). */
    fun byUri(uri: Uri): String = URI + uri

    fun displayName(context: Context, uri: Uri): String? = try {
        context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
            if (c.moveToFirst()) c.getString(0) else null
        }
    } catch (_: Exception) {
        null
    }

    fun ringtoneTitle(context: Context, uri: Uri): String? = try {
        RingtoneManager.getRingtone(context, uri)?.getTitle(context)
    } catch (_: Exception) {
        null
    }

    /** Removes copied sounds no alarm uses (not ones picked in the last hour: an editor may be open). */
    fun prune(context: Context) {
        try {
            val used = AlarmStore.load(context).mapNotNull { it.sound?.removePrefix(FILE) }.toSet()
            val recent = System.currentTimeMillis() - 60 * 60_000L
            dir(context).listFiles()?.forEach { f ->
                if (f.name !in used && f.lastModified() < recent) f.delete()
            }
        } catch (_: Exception) {
        }
    }

    /**
     * A player for [sound], on the alarm volume and prepared, or null when
     * it can't be played. Null [sound] is the app's chime. It loops unless
     * [looping] is false (a preview in the editor).
     */
    fun player(
        context: Context,
        sound: String?,
        attributes: AudioAttributes,
        looping: Boolean = true,
    ): MediaPlayer? {
        val player = MediaPlayer()
        fun raw(id: Int) = context.resources.openRawResourceFd(id).use { fd ->
            player.setDataSource(fd.fileDescriptor, fd.startOffset, fd.length)
        }
        return try {
            player.setAudioAttributes(attributes)
            when {
                sound == null -> raw(R.raw.alarm_default)
                sound.startsWith(BUILT_IN) ->
                    raw(builtIn[sound.removePrefix(BUILT_IN)] ?: throw IllegalStateException("unknown"))
                sound == SYSTEM -> player.setDataSource(
                    context,
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM),
                )
                sound.startsWith(FILE) -> {
                    val f = File(dir(context), sound.removePrefix(FILE))
                    if (!f.isFile) throw IllegalStateException("missing")
                    player.setDataSource(f.path)
                }
                sound.startsWith(URI) -> player.setDataSource(context, Uri.parse(sound.removePrefix(URI)))
                else -> throw IllegalStateException("unknown")
            }
            player.isLooping = looping
            player.prepare()
            player
        } catch (_: Exception) {
            try {
                player.release()
            } catch (_: Exception) {
            }
            null
        }
    }
}

/** Plays a sound once in the editor, on the alarm volume, so it sounds as it will. */
object SoundPreview {
    private var player: MediaPlayer? = null

    fun play(context: Context, sound: String?) {
        stop()
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val p = Sounds.player(context.applicationContext, sound, attributes, looping = false) ?: return
        player = p
        try {
            p.setOnCompletionListener { if (player === it) stop() }
            p.start()
        } catch (_: Exception) {
            stop()
        }
    }

    fun stop() {
        val p = player ?: return
        player = null
        try {
            p.stop()
        } catch (_: Exception) {
        }
        try {
            p.release()
        } catch (_: Exception) {
        }
    }
}

package dev.sagron.zerotrustclock.engine

import android.content.Context
import android.util.AtomicFile
import dev.sagron.zerotrustclock.engine.core.ClockTimer
import dev.sagron.zerotrustclock.engine.core.Stopwatch
import java.io.File

/**
 * Timers and the stopwatch, in device-protected storage like the alarms:
 * a timer that ends before the first unlock after a restart still rings.
 */
object TimerStore {
    private val lock = Any()
    private const val FILE = "timers.json"

    private fun file(context: Context) = AtomicFile(File(AlarmStore.deviceContext(context).filesDir, FILE))

    fun load(context: Context): List<ClockTimer> = synchronized(lock) { read(context) }

    /** Reads, changes and writes in one step, so two changes never overlap. */
    fun <T> update(context: Context, change: (MutableList<ClockTimer>) -> T): T = synchronized(lock) {
        val list = read(context).toMutableList()
        val before = ClockTimer.listToJson(list)
        val result = change(list)
        val after = ClockTimer.listToJson(list)
        if (after != before) write(context, after)
        result
    }

    private fun read(context: Context): List<ClockTimer> = try {
        ClockTimer.listFromJson(String(file(context).readFully(), Charsets.UTF_8))
    } catch (_: Exception) {
        emptyList()
    }

    private fun write(context: Context, json: String) {
        val f = file(context)
        val out = f.startWrite()
        try {
            out.write(json.toByteArray(Charsets.UTF_8))
            f.finishWrite(out)
        } catch (e: Exception) {
            f.failWrite(out)
            throw e
        }
    }

    private fun prefs(context: Context) =
        AlarmStore.deviceContext(context).getSharedPreferences("stopwatch", Context.MODE_PRIVATE)

    fun stopwatch(context: Context): Stopwatch = synchronized(lock) {
        Stopwatch.fromJson(prefs(context).getString("state", null))
    }

    fun updateStopwatch(context: Context, change: (Stopwatch) -> Stopwatch): Stopwatch = synchronized(lock) {
        val next = change(Stopwatch.fromJson(prefs(context).getString("state", null)))
        prefs(context).edit().putString("state", next.toJson()).commit()
        next
    }
}

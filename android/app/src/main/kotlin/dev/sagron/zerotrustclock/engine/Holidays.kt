package dev.sagron.zerotrustclock.engine

import android.content.Context
import dev.sagron.zerotrustclock.engine.core.AlarmSchedule
import java.time.LocalDate
import org.json.JSONArray

/**
 * The public holidays alarms with "Skip public holidays" stay silent on.
 * The app picks them (from the holiday calendar chosen in Settings, minus
 * days the user keeps) and hands them over as plain dates, kept in
 * storage readable before the first unlock. This phone only.
 */
object Holidays {
    private fun prefs(context: Context) =
        AlarmStore.deviceContext(context).getSharedPreferences("holidays", Context.MODE_PRIVATE)

    @Volatile
    private var cache: Set<LocalDate>? = null

    fun days(context: Context): Set<LocalDate> {
        cache?.let { return it }
        val out = HashSet<LocalDate>()
        try {
            val a = JSONArray(prefs(context).getString("days", "[]"))
            for (i in 0 until a.length()) AlarmSchedule.parseDay(a.optString(i))?.let { out.add(it) }
        } catch (_: Exception) {
        }
        cache = out
        return out
    }

    /** Replaces the list (yyyy-MM-dd) and sets every alarm again. */
    fun set(context: Context, days: List<String>) {
        val parsed = days.mapNotNull { AlarmSchedule.parseDay(it) }.toSortedSet()
        prefs(context).edit()
            .putString("days", JSONArray().also { a -> parsed.forEach { a.put(it.toString()) } }.toString())
            .apply()
        cache = parsed
        AlarmScheduler.rescheduleAll(context)
    }
}

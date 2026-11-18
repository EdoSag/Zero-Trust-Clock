package dev.sagron.zerotrustclock.engine.core

import org.json.JSONArray
import org.json.JSONObject

/**
 * One alarm, as the engine keeps it on the phone.
 *
 * Everything here is what is needed to ring, so it can live in storage
 * that is readable before the phone's first unlock. The label is kept
 * elsewhere (see LabelStore) because it can be private.
 */
data class Alarm(
    val id: String,
    /** Small number that names this alarm to Android's AlarmManager. */
    val code: Int,
    val hour: Int,
    val minute: Int,
    /** Repeat days, ISO numbers 1 = Monday .. 7 = Sunday. Empty: rings once. */
    val days: Set<Int> = emptySet(),
    val enabled: Boolean = true,
    /** Rings once: the day it rings (yyyy-MM-dd). Null for repeating alarms. */
    val date: String? = null,
    /**
     * "Turn off once": the day of the one ring that is skipped
     * (yyyy-MM-dd). The alarm stays on; the scheduler simply picks the
     * first ring after this day, so nothing has to run to turn it back on.
     */
    val skipDate: String? = null,
    val vibrate: Boolean = true,
    val snoozeMinutes: Int = 10,
    /** While snoozed: when it rings again (epoch milliseconds). */
    val snoozeUntil: Long? = null,
    /** The time last handed to AlarmManager, to notice a ring that never came. */
    val armedFor: Long? = null,
    /** The Alarm check screen's test alarm; removed after it rings. */
    val test: Boolean = false,
    val updatedAt: Long = 0,
) {
    val repeats: Boolean get() = days.isNotEmpty()

    fun toJson(): JSONObject = JSONObject().apply {
        put("id", id)
        put("code", code)
        put("hour", hour)
        put("minute", minute)
        put("days", JSONArray().also { a -> days.sorted().forEach { a.put(it) } })
        put("enabled", enabled)
        if (date != null) put("date", date)
        if (skipDate != null) put("skipDate", skipDate)
        put("vibrate", vibrate)
        put("snoozeMinutes", snoozeMinutes)
        if (snoozeUntil != null) put("snoozeUntil", snoozeUntil)
        if (armedFor != null) put("armedFor", armedFor)
        if (test) put("test", true)
        put("updatedAt", updatedAt)
    }

    companion object {
        fun fromJson(o: JSONObject): Alarm {
            val days = mutableSetOf<Int>()
            val a = o.optJSONArray("days")
            if (a != null) {
                for (i in 0 until a.length()) {
                    val d = a.optInt(i, 0)
                    if (d in 1..7) days.add(d)
                }
            }
            return Alarm(
                id = o.getString("id"),
                code = o.getInt("code"),
                hour = o.getInt("hour").coerceIn(0, 23),
                minute = o.getInt("minute").coerceIn(0, 59),
                days = days,
                enabled = o.optBoolean("enabled", true),
                date = text(o, "date"),
                skipDate = text(o, "skipDate"),
                vibrate = o.optBoolean("vibrate", true),
                snoozeMinutes = o.optInt("snoozeMinutes", 10).coerceIn(1, 60),
                snoozeUntil = number(o, "snoozeUntil"),
                armedFor = number(o, "armedFor"),
                test = o.optBoolean("test", false),
                updatedAt = o.optLong("updatedAt", 0),
            )
        }

        fun listToJson(alarms: List<Alarm>): String =
            JSONArray().also { a -> alarms.forEach { a.put(it.toJson()) } }.toString()

        /** Skips entries that can't be read, so one bad entry doesn't lose the rest. */
        fun listFromJson(json: String): List<Alarm> {
            val a = JSONArray(json)
            val out = ArrayList<Alarm>(a.length())
            for (i in 0 until a.length()) {
                try {
                    out.add(fromJson(a.getJSONObject(i)))
                } catch (_: Exception) {
                }
            }
            return out
        }

        private fun text(o: JSONObject, key: String): String? =
            if (o.has(key) && !o.isNull(key)) o.optString(key).takeIf { it.isNotEmpty() } else null

        private fun number(o: JSONObject, key: String): Long? =
            if (o.has(key) && !o.isNull(key)) o.optLong(key) else null
    }
}

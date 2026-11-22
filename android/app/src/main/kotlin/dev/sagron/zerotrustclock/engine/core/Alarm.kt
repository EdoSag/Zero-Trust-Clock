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
    /**
     * "Pause until": a repeating alarm stays silent through this day
     * (yyyy-MM-dd) and rings again after it, by itself.
     */
    val pauseUntil: String? = null,
    /**
     * The sound: null for the app's own chime, "system" for the phone's
     * alarm sound, or "file:<name>" for a sound copied into the app (see
     * Sounds), so it also plays before the first unlock.
     */
    val sound: String? = null,
    /** What the sound is called, to show in the editor. */
    val soundName: String? = null,
    /** Starts quietly and gets louder over a minute. */
    val gradual: Boolean = false,
    /** An unanswered ring stops by itself after this many minutes. */
    val ringMinutes: Int = DEFAULT_RING_MINUTES,
    /** A wake-up task (see WakeTasks) to do before it can be dismissed. */
    val task: String? = null,
    /** For the scan task: the saved code, as WakeTasks.codeHash keeps it. */
    val taskCode: String? = null,
    /** A repeating alarm stays silent on this phone's public holidays (see Holidays). */
    val skipHolidays: Boolean = false,
    /**
     * A shift pattern instead of weekdays: one character per day of the
     * cycle, '1' rings and '0' is a day off ("11000000": two days on, six
     * off). Day 1 of the cycle is [cycleStart]. [days] is empty then.
     */
    val cycle: String? = null,
    /** The first day of the shift pattern's cycle (yyyy-MM-dd). */
    val cycleStart: String? = null,
    /** Linked to ZT Calendar: rings in time for the day's first event. */
    val calendar: CalendarLink? = null,
    /**
     * The day's first event as ZT Calendar had it the last time the app
     * read it: minutes after midnight, by day (yyyy-MM-dd). A day up to
     * [calendarThrough] that isn't here has no event. Times only: what the
     * events are stays in the app. This phone only.
     */
    val calendarPlan: Map<String, Int> = emptyMap(),
    /** The last day [calendarPlan] covers; after it the usual time rings. */
    val calendarThrough: String? = null,
    /** Smart wake window: may ring up to this many minutes early when the phone feels movement. 0: off. */
    val smartWake: Int = 0,
    /**
     * A ring at or before this moment already happened (epoch
     * milliseconds): the smart wake window rang early for it.
     */
    val servedUntil: Long? = null,
) {
    val repeats: Boolean get() = days.isNotEmpty() || shift != null

    /** The shift pattern, when it is a valid one. */
    val shift: ShiftPattern? get() = ShiftPattern.of(cycle, cycleStart)

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
        if (pauseUntil != null) put("pauseUntil", pauseUntil)
        if (sound != null) put("sound", sound)
        if (soundName != null) put("soundName", soundName)
        put("gradual", gradual)
        put("ringMinutes", ringMinutes)
        if (task != null) put("task", task)
        if (taskCode != null) put("taskCode", taskCode)
        if (skipHolidays) put("skipHolidays", true)
        if (cycle != null) put("cycle", cycle)
        if (cycleStart != null) put("cycleStart", cycleStart)
        calendar?.let { put("calendar", it.toJson()) }
        if (calendarPlan.isNotEmpty()) {
            put("calendarPlan", JSONObject().also { o -> calendarPlan.toSortedMap().forEach { (k, v) -> o.put(k, v) } })
        }
        if (calendarThrough != null) put("calendarThrough", calendarThrough)
        if (smartWake > 0) put("smartWake", smartWake)
        if (servedUntil != null) put("servedUntil", servedUntil)
    }

    companion object {
        const val DEFAULT_RING_MINUTES = 10

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
                pauseUntil = text(o, "pauseUntil"),
                sound = text(o, "sound"),
                soundName = text(o, "soundName"),
                gradual = o.optBoolean("gradual", false),
                ringMinutes = o.optInt("ringMinutes", DEFAULT_RING_MINUTES).coerceIn(1, 60),
                task = WakeTasks.parse(text(o, "task"), text(o, "taskCode")),
                taskCode = WakeTasks.parseCode(text(o, "taskCode")),
                skipHolidays = o.optBoolean("skipHolidays", false),
                cycle = text(o, "cycle"),
                cycleStart = text(o, "cycleStart"),
                calendar = o.optJSONObject("calendar")?.let { CalendarLink.fromJson(it) },
                calendarPlan = plan(o.optJSONObject("calendarPlan")),
                calendarThrough = text(o, "calendarThrough"),
                smartWake = SmartWake.parse(o.optInt("smartWake", 0)),
                servedUntil = number(o, "servedUntil"),
            )
        }

        /** Days with their first event, minutes after midnight. */
        fun plan(o: JSONObject?): Map<String, Int> {
            if (o == null) return emptyMap()
            val out = HashMap<String, Int>()
            for (k in o.keys()) {
                val v = o.optInt(k, -1)
                if (v in 0 until 24 * 60 && AlarmSchedule.parseDay(k) != null) out[k] = v
            }
            return out
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

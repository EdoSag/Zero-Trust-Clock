package dev.sagron.zerotrustclock.engine.core

import java.time.LocalDate
import org.json.JSONArray
import org.json.JSONObject

/**
 * One day of the morning screen: what ZT Calendar, ZT Tasks and ZT Quests
 * have for it, as the app worked it out at its last unlock.
 *
 * The app sends `{"through": "yyyy-MM-dd", "days": {"yyyy-MM-dd": {...}}}`;
 * a day up to `through` that isn't listed has nothing planned. Kept in
 * the phone's normal (unlock-protected) storage: before the first unlock
 * there is no morning screen.
 */
data class MorningDay(
    val events: Int = 0,
    /** The first event's start, minutes after midnight, or null. */
    val firstEvent: Int? = null,
    /** The first few events: start (minutes after midnight, null all day) and title. */
    val eventList: List<Pair<Int?, String>> = emptyList(),
    val tasks: Int = 0,
    val overdue: Int = 0,
    val taskList: List<String> = emptyList(),
    val quests: Int = 0,
    val questList: List<String> = emptyList(),
) {
    val empty: Boolean get() = events == 0 && tasks == 0 && overdue == 0 && quests == 0

    companion object {
        /** At most this many names per row. */
        const val LIST_MAX = 4

        /** [day]'s entry, or null when the brief doesn't reach that day (or can't be read). */
        fun of(json: String?, day: LocalDate): MorningDay? {
            if (json.isNullOrBlank()) return null
            return try {
                val o = JSONObject(json)
                val through = AlarmSchedule.parseDay(o.optString("through", "")) ?: return null
                if (day.isAfter(through)) return null
                val d = o.optJSONObject("days")?.optJSONObject(day.toString()) ?: return MorningDay()
                fromJson(d)
            } catch (_: Exception) {
                null
            }
        }

        fun fromJson(o: JSONObject): MorningDay {
            fun count(key: String) = o.optInt(key, 0).coerceAtLeast(0)
            fun names(a: JSONArray?): List<String> {
                if (a == null) return emptyList()
                val out = ArrayList<String>()
                for (i in 0 until a.length()) {
                    val s = a.optString(i, "").trim()
                    if (s.isNotEmpty() && out.size < LIST_MAX) out.add(s)
                }
                return out
            }
            val events = ArrayList<Pair<Int?, String>>()
            o.optJSONArray("eventList")?.let { a ->
                for (i in 0 until a.length()) {
                    val e = a.optJSONObject(i) ?: continue
                    val title = e.optString("title", "").trim()
                    val t = if (e.has("t") && !e.isNull("t")) e.optInt("t", -1) else -1
                    if (events.size < LIST_MAX) events.add(Pair(t.takeIf { it in 0 until 24 * 60 }, title))
                }
            }
            val first = if (o.has("first") && !o.isNull("first")) o.optInt("first", -1) else -1
            return MorningDay(
                events = count("events"),
                firstEvent = first.takeIf { it in 0 until 24 * 60 },
                eventList = events,
                tasks = count("tasks"),
                overdue = count("overdue"),
                taskList = names(o.optJSONArray("taskList")),
                quests = count("quests"),
                questList = names(o.optJSONArray("questList")),
            )
        }
    }
}

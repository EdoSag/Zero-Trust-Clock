package dev.sagron.zerotrustclock.engine.core

import org.json.JSONArray
import org.json.JSONObject

/**
 * The stopwatch. [startedAt] is set while it runs; [banked] is the time
 * counted before the last start. [laps] are the total times at each lap
 * press, oldest first.
 */
data class Stopwatch(
    val startedAt: Long? = null,
    val banked: Long = 0,
    val laps: List<Long> = emptyList(),
) {
    val running: Boolean get() = startedAt != null
    val zero: Boolean get() = !running && banked == 0L && laps.isEmpty()

    fun elapsed(now: Long): Long = banked + if (startedAt == null) 0 else (now - startedAt).coerceAtLeast(0)

    fun start(now: Long): Stopwatch = if (running) this else copy(startedAt = now)

    fun pause(now: Long): Stopwatch = if (!running) this else Stopwatch(null, elapsed(now), laps)

    /** Keeps at most [MAX_LAPS]; a lap press while paused does nothing. */
    fun lap(now: Long): Stopwatch =
        if (!running || laps.size >= MAX_LAPS) this else copy(laps = laps + elapsed(now))

    fun reset(): Stopwatch = Stopwatch()

    fun toJson(): String = JSONObject().apply {
        if (startedAt != null) put("startedAt", startedAt)
        put("banked", banked)
        put("laps", JSONArray().also { a -> laps.forEach { a.put(it) } })
    }.toString()

    companion object {
        const val MAX_LAPS = 999

        fun fromJson(text: String?): Stopwatch {
            if (text.isNullOrEmpty()) return Stopwatch()
            return try {
                val o = JSONObject(text)
                val a = o.optJSONArray("laps") ?: JSONArray()
                Stopwatch(
                    startedAt = if (o.has("startedAt") && !o.isNull("startedAt")) o.getLong("startedAt") else null,
                    banked = o.optLong("banked", 0),
                    laps = (0 until a.length()).map { a.getLong(it) },
                )
            } catch (_: Exception) {
                Stopwatch()
            }
        }
    }
}

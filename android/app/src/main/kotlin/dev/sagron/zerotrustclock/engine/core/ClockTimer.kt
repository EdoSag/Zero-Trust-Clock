package dev.sagron.zerotrustclock.engine.core

import org.json.JSONArray
import org.json.JSONObject

/**
 * One countdown timer. Several can run at once.
 *
 * It is in one of four states:
 * - set (not started, or reset): [endsAt] null and [leftMs] == [lengthMs];
 * - running: [endsAt] is when it reaches zero;
 * - paused: [endsAt] null and [leftMs] is what was left;
 * - ringing: [ringing] true, [endsAt] is when it reached zero.
 *
 * Times are wall-clock epoch milliseconds, so a timer survives a restart
 * of the phone (a timer that ended while the phone was off rings at once).
 */
data class ClockTimer(
    val id: String,
    /** Small number that names this timer to Android's AlarmManager. */
    val code: Int,
    /** The length it was set to; Reset goes back to it. */
    val lengthMs: Long,
    val label: String = "",
    val endsAt: Long? = null,
    val leftMs: Long = lengthMs,
    val ringing: Boolean = false,
    val createdAt: Long = 0,
) {
    val running: Boolean get() = endsAt != null && !ringing
    val paused: Boolean get() = endsAt == null && !ringing && leftMs != lengthMs

    /** Time left; negative while ringing (how long ago it ended). */
    fun left(now: Long): Long = when {
        endsAt != null -> endsAt - now
        else -> leftMs
    }

    fun toJson(): JSONObject = JSONObject().apply {
        put("id", id)
        put("code", code)
        put("lengthMs", lengthMs)
        put("label", label)
        if (endsAt != null) put("endsAt", endsAt)
        put("leftMs", leftMs)
        put("ringing", ringing)
        put("createdAt", createdAt)
    }

    companion object {
        const val MINUTE_MS = 60_000L

        /** Longest timer: 99 hours 59 minutes 59 seconds, as the keypad allows. */
        const val MAX_MS = (99 * 3600 + 59 * 60 + 59) * 1000L

        fun fromJson(o: JSONObject): ClockTimer {
            val length = o.getLong("lengthMs")
            return ClockTimer(
                id = o.getString("id"),
                code = o.getInt("code"),
                lengthMs = length,
                label = o.optString("label", ""),
                endsAt = if (o.has("endsAt") && !o.isNull("endsAt")) o.getLong("endsAt") else null,
                leftMs = o.optLong("leftMs", length),
                ringing = o.optBoolean("ringing", false),
                createdAt = o.optLong("createdAt", 0),
            )
        }

        fun listToJson(list: List<ClockTimer>): String =
            JSONArray().also { a -> list.forEach { a.put(it.toJson()) } }.toString()

        fun listFromJson(text: String): List<ClockTimer> {
            val a = JSONArray(text)
            return (0 until a.length()).mapNotNull {
                try {
                    fromJson(a.getJSONObject(it))
                } catch (_: Exception) {
                    null
                }
            }
        }
    }
}

/** What each button does to a timer. Pure: no Android, unit tested. */
object TimerMath {
    fun start(t: ClockTimer, now: Long): ClockTimer = when {
        t.running || t.ringing -> t
        else -> t.copy(endsAt = now + t.leftMs.coerceAtLeast(0))
    }

    fun pause(t: ClockTimer, now: Long): ClockTimer =
        if (!t.running) t else t.copy(endsAt = null, leftMs = (t.endsAt!! - now).coerceAtLeast(0))

    /** "+1:00". A ringing timer stops ringing and runs for one more minute. */
    fun addMinute(t: ClockTimer, now: Long): ClockTimer = when {
        t.ringing -> t.copy(ringing = false, endsAt = now + ClockTimer.MINUTE_MS)
        t.endsAt != null -> t.copy(endsAt = minOf(t.endsAt + ClockTimer.MINUTE_MS, now + ClockTimer.MAX_MS))
        else -> t.copy(leftMs = minOf(t.leftMs + ClockTimer.MINUTE_MS, ClockTimer.MAX_MS))
    }

    /** Back to its length, not running. Also what "Stop" does to a ringing timer. */
    fun reset(t: ClockTimer): ClockTimer = t.copy(endsAt = null, leftMs = t.lengthMs, ringing = false)

    fun ring(t: ClockTimer): ClockTimer = if (t.running) t.copy(ringing = true) else t

    /** Running timers whose time has come. */
    fun due(list: List<ClockTimer>, now: Long): List<ClockTimer> =
        list.filter { it.running && it.endsAt!! <= now }

    /**
     * The one timer a small place (the widget, the tile) shows: one that
     * rings, else the running one that ends first, else a paused one, else
     * one that is set but not started (the newest of each). Null with no
     * timers.
     */
    fun featured(list: List<ClockTimer>): ClockTimer? =
        list.filter { it.ringing }.minByOrNull { it.endsAt ?: 0 }
            ?: list.filter { it.running }.minByOrNull { it.endsAt!! }
            ?: list.filter { it.paused }.maxByOrNull { it.createdAt }
            ?: list.maxByOrNull { it.createdAt }

    /** A number for AlarmManager that no other timer uses. */
    fun freeCode(list: List<ClockTimer>): Int {
        val used = list.map { it.code }.toSet()
        var c = 1
        while (c in used) c++
        return c
    }
}

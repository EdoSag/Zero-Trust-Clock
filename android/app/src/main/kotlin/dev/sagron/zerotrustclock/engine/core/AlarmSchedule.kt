package dev.sagron.zerotrustclock.engine.core

import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZonedDateTime

/**
 * When an alarm rings. The only place that decides it: the app's screens
 * ask the engine instead of working it out again, so the time shown is
 * always the time it rings.
 *
 * No Android here, so it is tested on any machine.
 */
object AlarmSchedule {
    /**
     * How late a ring may still start. A phone switched on a few minutes
     * after the alarm time rings at once; later than this it is reported
     * as missed instead.
     */
    const val LATE_RING_MS = 10 * 60_000L

    /** One planned ring: the calendar day it belongs to, and the moment. */
    data class Ring(val day: LocalDate, val at: ZonedDateTime)

    /**
     * The moment an alarm rings on [day]. A time that doesn't exist that
     * day (clocks go forward) rings as soon as the gap ends; a time that
     * happens twice (clocks go back) rings the first time only.
     */
    fun ringOn(alarm: Alarm, day: LocalDate, zone: ZoneId): ZonedDateTime =
        ZonedDateTime.of(day, LocalTime.of(alarm.hour, alarm.minute), zone)

    /**
     * The last silent day of a pause: the alarm's own "Pause until" or
     * [pauseAll] ("Pause all alarms until"), whichever ends later. Only
     * repeating alarms pause; one set for a single day still rings.
     */
    fun pausedThrough(alarm: Alarm, pauseAll: LocalDate?): LocalDate? {
        if (!alarm.repeats) return null
        return listOfNotNull(parseDay(alarm.pauseUntil), pauseAll).maxOrNull()
    }

    /** True while a pause keeps the alarm silent. */
    fun paused(alarm: Alarm, now: ZonedDateTime, pauseAll: LocalDate? = null): Boolean {
        val through = pausedThrough(alarm, pauseAll) ?: return false
        return alarm.enabled && !through.isBefore(now.toLocalDate())
    }

    /**
     * The next regular ring after [now], without snooze. Null when the
     * alarm is off, or rings once and that time has passed.
     */
    fun nextRing(
        alarm: Alarm,
        now: ZonedDateTime,
        pauseAll: LocalDate? = null,
        holidays: Set<LocalDate> = emptySet(),
    ): Ring? {
        if (!alarm.enabled) return null
        val zone = now.zone
        if (!alarm.repeats) {
            val day = parseDay(alarm.date) ?: return null
            val at = ringOn(alarm, day, zone)
            return if (at.isAfter(now)) Ring(day, at) else null
        }
        val skip = parseDay(alarm.skipDate)
        val today = now.toLocalDate()
        val paused = pausedThrough(alarm, pauseAll)
        val first = if (paused != null && !paused.isBefore(today)) paused.plusDays(1) else today
        // Covers a skipped ring of a once-a-week alarm, and a week of
        // holidays (Sukkot, Passover) on top of it.
        for (d in 0L..40L) {
            val day = first.plusDays(d)
            if (day.dayOfWeek.value !in alarm.days) continue
            if (day == skip) continue
            if (alarm.skipHolidays && day in holidays) continue
            val at = ringOn(alarm, day, zone)
            if (at.isAfter(now)) return Ring(day, at)
        }
        return null
    }

    /**
     * What AlarmManager is set to: the snooze end while snoozed, else the
     * next ring. Epoch milliseconds, or null when nothing is due.
     */
    fun nextTrigger(
        alarm: Alarm,
        now: ZonedDateTime,
        pauseAll: LocalDate? = null,
        holidays: Set<LocalDate> = emptySet(),
    ): Long? {
        if (!alarm.enabled) return null
        alarm.snoozeUntil?.let { return it }
        return nextRing(alarm, now, pauseAll, holidays)?.at?.toInstant()?.toEpochMilli()
    }

    /** True while a "Turn off once" is still waiting for its skipped ring. */
    fun skipActive(alarm: Alarm, now: ZonedDateTime): Boolean {
        if (!alarm.enabled) return false
        val skip = parseDay(alarm.skipDate) ?: return false
        return ringOn(alarm, skip, now.zone).isAfter(now)
    }

    /** Switched on by hand: any skip, pause or snooze is forgotten. */
    fun turnOn(alarm: Alarm, now: ZonedDateTime): Alarm = withTime(
        alarm.copy(enabled = true, pauseUntil = null), alarm.hour, alarm.minute, alarm.days, now,
    )

    fun turnOff(alarm: Alarm): Alarm =
        alarm.copy(enabled = false, skipDate = null, pauseUntil = null, snoozeUntil = null, armedFor = null)

    /**
     * "Pause until": silent through [until], on again the day after by
     * itself (nothing has to run for that). A waiting skip is dropped.
     */
    fun pause(alarm: Alarm, until: LocalDate): Alarm =
        if (!alarm.repeats) alarm else alarm.copy(pauseUntil = until.toString(), skipDate = null, snoozeUntil = null)

    fun resume(alarm: Alarm): Alarm = alarm.copy(pauseUntil = null)

    /**
     * Sets the time and days. A changed alarm starts fresh: no skip, no
     * snooze. One that rings once gets the first such time after [now].
     */
    fun withTime(alarm: Alarm, hour: Int, minute: Int, days: Set<Int>, now: ZonedDateTime): Alarm {
        val base = alarm.copy(
            hour = hour, minute = minute, days = days,
            skipDate = null, snoozeUntil = null, armedFor = null,
        )
        if (days.isNotEmpty()) return base.copy(date = null)
        val today = now.toLocalDate()
        val day = if (ringOn(base, today, now.zone).isAfter(now)) today else today.plusDays(1)
        return base.copy(date = day.toString())
    }

    /**
     * "Turn off once". A repeating alarm skips its next ring. One that
     * rings once moves a day forward (Edo's choice, 2026-11-18). Either
     * way it stays on.
     */
    fun skipOnce(
        alarm: Alarm,
        now: ZonedDateTime,
        pauseAll: LocalDate? = null,
        holidays: Set<LocalDate> = emptySet(),
    ): Alarm {
        if (!alarm.enabled) return alarm
        val fresh = alarm.copy(skipDate = null, snoozeUntil = null)
        val next = nextRing(fresh, now, pauseAll, holidays) ?: return alarm
        return if (alarm.repeats) {
            fresh.copy(skipDate = next.day.toString())
        } else {
            fresh.copy(skipDate = next.day.toString(), date = next.day.plusDays(1).toString())
        }
    }

    /** "Turn back on": undoes [skipOnce] while the skipped ring is still ahead. */
    fun undoSkip(alarm: Alarm, now: ZonedDateTime): Alarm {
        val skip = parseDay(alarm.skipDate) ?: return alarm
        if (alarm.repeats) return alarm.copy(skipDate = null)
        val original = ringOn(alarm, skip, now.zone)
        return if (original.isAfter(now)) {
            alarm.copy(skipDate = null, date = skip.toString())
        } else {
            alarm.copy(skipDate = null)
        }
    }

    fun snooze(alarm: Alarm, now: ZonedDateTime): Alarm = alarm.copy(
        snoozeUntil = now.toInstant().toEpochMilli() + alarm.snoozeMinutes * 60_000L,
    )

    /**
     * After a ring ended (dismissed, timed out or missed): one that rings
     * once is switched off, a repeating one just waits for its next day.
     */
    fun afterRing(alarm: Alarm, now: ZonedDateTime): Alarm {
        val done = alarm.copy(snoozeUntil = null, armedFor = null)
        if (!alarm.repeats) return done.copy(enabled = false, date = null, skipDate = null)
        return tidy(done, now)
    }

    /** Drops a skip whose day has passed, and a pause that has ended. */
    fun tidy(alarm: Alarm, now: ZonedDateTime): Alarm {
        var a = alarm
        if (a.skipDate != null && !skipActive(a, now)) a = a.copy(skipDate = null)
        val pause = parseDay(a.pauseUntil)
        if (a.pauseUntil != null && (pause == null || pause.isBefore(now.toLocalDate()))) a = a.copy(pauseUntil = null)
        return a
    }

    /**
     * The time handed to AlarmManager has passed and the ring hasn't
     * started (the phone was off, or just restarted): ring now, late.
     */
    fun dueNow(alarm: Alarm, nowMs: Long): Boolean {
        val armed = alarm.armedFor ?: return false
        return alarm.enabled && armed <= nowMs && nowMs - armed <= LATE_RING_MS
    }

    /** As [dueNow], but too late to still ring: it is reported as missed. */
    fun wasMissed(alarm: Alarm, nowMs: Long): Boolean {
        val armed = alarm.armedFor ?: return false
        return alarm.enabled && nowMs - armed > LATE_RING_MS
    }

    fun at(ms: Long, zone: ZoneId): ZonedDateTime = Instant.ofEpochMilli(ms).atZone(zone)

    fun parseDay(day: String?): LocalDate? = try {
        if (day == null) null else LocalDate.parse(day)
    } catch (_: Exception) {
        null
    }
}

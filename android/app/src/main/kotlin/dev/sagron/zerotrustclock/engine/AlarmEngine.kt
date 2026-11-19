package dev.sagron.zerotrustclock.engine

import android.content.Context
import dev.sagron.zerotrustclock.engine.core.Alarm
import dev.sagron.zerotrustclock.engine.core.AlarmSchedule
import java.time.ZoneId
import java.time.ZonedDateTime
import java.util.UUID
import org.json.JSONArray

/** What the app's screens (and notification buttons) can do with alarms. */
object AlarmEngine {
    fun now(): ZonedDateTime = ZonedDateTime.now(ZoneId.systemDefault())

    /**
     * The alarms as the screens show them: each with its label, its next
     * ring (after any "Turn off once" or pause) and whether a skip or a
     * pause is waiting.
     */
    fun listJson(context: Context): String {
        val now = now()
        val pauseAll = EnginePrefs.pauseAllUntil(context)
        val out = JSONArray()
        for (a in AlarmStore.load(context)) {
            if (a.test) continue
            val o = a.toJson()
            o.remove("armedFor")
            o.remove("code")
            o.put("label", LabelStore.get(context, a.id))
            val next = AlarmSchedule.nextRing(a, now, pauseAll)
            if (next != null) o.put("nextRing", next.at.toInstant().toEpochMilli())
            o.put("skipActive", AlarmSchedule.skipActive(a, now))
            o.put("paused", AlarmSchedule.paused(a, now, pauseAll))
            o.put("ringing", a.id == RingService.ringingId)
            out.put(o)
        }
        return out.toString()
    }

    /** "Pause all alarms until", or null when none is set. */
    fun pauseAllUntil(context: Context): String? = EnginePrefs.pauseAllUntil(context)?.toString()

    /** Everything about an alarm besides its time and days. */
    data class Options(
        val label: String = "",
        val vibrate: Boolean = true,
        val snoozeMinutes: Int = 10,
        val sound: String? = null,
        val soundName: String? = null,
        val gradual: Boolean = false,
        val ringMinutes: Int = Alarm.DEFAULT_RING_MINUTES,
        /** Rings once on this day (yyyy-MM-dd); null: the next such time. */
        val date: String? = null,
    )

    /**
     * Adds an alarm ([id] null) or changes one. A new or re-timed alarm is
     * switched on. An alarm without repeat days rings on [Options.date] when
     * that time is still ahead, else at the next such time.
     */
    fun save(
        context: Context,
        id: String?,
        hour: Int,
        minute: Int,
        days: Set<Int>,
        options: Options,
    ): String {
        val now = now()
        val pickedDay = if (days.isEmpty()) AlarmSchedule.parseDay(options.date) else null
        val saved = AlarmStore.update(context) { list ->
            val i = if (id == null) -1 else list.indexOfFirst { it.id == id }
            val old = if (i >= 0) list[i] else null
            var alarm = if (old == null) {
                AlarmSchedule.withTime(
                    Alarm(
                        id = id ?: UUID.randomUUID().toString(),
                        code = (list.maxOfOrNull { it.code } ?: 0) + 1,
                        hour = hour,
                        minute = minute,
                    ),
                    hour, minute, days, now,
                )
            } else if (old.hour != hour || old.minute != minute || old.days != days ||
                (pickedDay != null && pickedDay.toString() != old.date)
            ) {
                AlarmSchedule.withTime(old.copy(enabled = true), hour, minute, days, now)
            } else {
                old
            }
            if (pickedDay != null && alarm.date != pickedDay.toString() &&
                AlarmSchedule.ringOn(alarm, pickedDay, now.zone).isAfter(now)
            ) {
                alarm = alarm.copy(date = pickedDay.toString(), enabled = true, skipDate = null)
            }
            alarm = alarm.copy(
                vibrate = options.vibrate,
                snoozeMinutes = options.snoozeMinutes.coerceIn(1, 60),
                sound = options.sound,
                soundName = if (options.sound == null) null else options.soundName,
                gradual = options.gradual,
                ringMinutes = options.ringMinutes.coerceIn(1, 60),
                updatedAt = if (old == null) System.currentTimeMillis() else editedAt(old),
            )
            if (i >= 0) list[i] = alarm else list.add(alarm)
            alarm
        }
        LabelStore.set(context, saved.id, options.label)
        AlarmNotifications.cancelSnoozed(context, saved.id)
        Sounds.prune(context)
        AlarmScheduler.rescheduleAll(context)
        return saved.id
    }

    fun setEnabled(context: Context, id: String, on: Boolean) = change(context, id) { a, now ->
        if (on) AlarmSchedule.turnOn(a, now) else AlarmSchedule.turnOff(a)
    }

    /** "Turn off once". */
    fun skipOnce(context: Context, id: String) = change(context, id) { a, now ->
        AlarmSchedule.skipOnce(a, now, EnginePrefs.pauseAllUntil(context))
    }

    /** "Pause until": silent through [until] (yyyy-MM-dd). */
    fun pause(context: Context, id: String, until: String) {
        val day = AlarmSchedule.parseDay(until) ?: return
        change(context, id) { a, _ -> AlarmSchedule.pause(a, day) }
    }

    fun resume(context: Context, id: String) = change(context, id) { a, _ -> AlarmSchedule.resume(a) }

    /** "Pause all alarms until" [until] (repeating ones), or null to end it. This phone only. */
    fun setPauseAll(context: Context, until: String?) {
        EnginePrefs.setPauseAllUntil(context, until?.let { AlarmSchedule.parseDay(it)?.toString() })
        AlarmScheduler.rescheduleAll(context)
    }

    /** "Turn back on". */
    fun undoSkip(context: Context, id: String) = change(context, id) { a, now -> AlarmSchedule.undoSkip(a, now) }

    /** Ends a snooze without ringing again. */
    fun cancelSnooze(context: Context, id: String) = change(context, id) { a, now ->
        if (a.snoozeUntil == null) a else AlarmSchedule.afterRing(a, now)
    }

    fun delete(context: Context, id: String) {
        AlarmStore.update(context) { list ->
            val i = list.indexOfFirst { it.id == id }
            if (i >= 0) {
                AlarmScheduler.cancel(context, list[i])
                UpcomingAlarms.forget(context, list[i])
                list.removeAt(i)
            }
        }
        LabelStore.remove(context, id)
        AlarmNotifications.cancelSnoozed(context, id)
        Sounds.prune(context)
        AlarmScheduler.rescheduleAll(context)
    }

    /**
     * Takes an alarm as the account's backup has it (another phone changed
     * it, or this phone is restoring). Only what syncs is taken; the sound
     * stays this phone's own, and a snooze on this phone stays unless the
     * time changed or it is switched off.
     * [enabled] is this phone's own switch: an alarm switched on elsewhere
     * arrives off here. Nothing is changed while it rings; false then, and
     * sync tries again later.
     */
    fun importSynced(
        context: Context,
        id: String,
        hour: Int,
        minute: Int,
        days: Set<Int>,
        date: String?,
        skipDate: String?,
        label: String,
        vibrate: Boolean,
        snoozeMinutes: Int,
        enabled: Boolean,
        updatedAt: Long,
        pauseUntil: String?,
        gradual: Boolean,
        ringMinutes: Int,
    ): Boolean {
        if (id == RingService.ringingId) return false
        AlarmStore.update(context) { list ->
            val i = list.indexOfFirst { it.id == id }
            val old = if (i >= 0) list[i] else null
            val retimed = old == null || old.hour != hour || old.minute != minute || old.days != days
            val keepSnooze = old?.snoozeUntil != null && enabled && !retimed
            val alarm = (old ?: Alarm(id = id, code = (list.maxOfOrNull { it.code } ?: 0) + 1, hour = hour, minute = minute))
                .copy(
                    hour = hour,
                    minute = minute,
                    days = days,
                    date = if (days.isEmpty()) date else null,
                    skipDate = skipDate,
                    vibrate = vibrate,
                    snoozeMinutes = snoozeMinutes,
                    enabled = enabled,
                    snoozeUntil = if (keepSnooze) old?.snoozeUntil else null,
                    updatedAt = updatedAt,
                    pauseUntil = if (days.isEmpty()) null else pauseUntil,
                    gradual = gradual,
                    ringMinutes = ringMinutes.coerceIn(1, 60),
                )
            if (i >= 0) list[i] = alarm else list.add(alarm)
            if (!keepSnooze) AlarmNotifications.cancelSnoozed(context, id)
        }
        LabelStore.set(context, id, label)
        AlarmScheduler.rescheduleAll(context)
        return true
    }

    /**
     * The Alarm check screen's test: a real alarm that rings in [seconds]
     * through the same path as every other one (so it also survives a
     * restart), and removes itself afterwards.
     */
    fun addTest(context: Context, seconds: Int) {
        val now = now()
        AlarmStore.update(context) { list ->
            list.filter { it.test }.forEach { AlarmScheduler.cancel(context, it) }
            list.removeAll { it.test }
            list.add(
                Alarm(
                    id = "test-" + UUID.randomUUID().toString(),
                    code = (list.maxOfOrNull { it.code } ?: 0) + 1,
                    hour = now.hour,
                    minute = now.minute,
                    date = now.toLocalDate().toString(),
                    snoozeUntil = now.toInstant().toEpochMilli() + seconds * 1000L,
                    test = true,
                    updatedAt = System.currentTimeMillis(),
                ),
            )
        }
        AlarmScheduler.rescheduleAll(context)
    }

    /**
     * The time of an edit by hand: now, but always after the alarm's last
     * edit. A version synced from a phone whose clock runs ahead must not
     * make this edit look older than it, or sync would undo it.
     */
    private fun editedAt(alarm: Alarm): Long = maxOf(System.currentTimeMillis(), alarm.updatedAt + 1)

    private fun change(context: Context, id: String, how: (Alarm, ZonedDateTime) -> Alarm) {
        val now = now()
        AlarmStore.update(context) { list ->
            val i = list.indexOfFirst { it.id == id }
            if (i >= 0) {
                list[i] = how(list[i], now).copy(updatedAt = editedAt(list[i]))
            }
        }
        AlarmNotifications.cancelSnoozed(context, id)
        AlarmScheduler.rescheduleAll(context)
    }
}

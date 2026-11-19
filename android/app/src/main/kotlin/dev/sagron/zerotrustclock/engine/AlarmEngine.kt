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
     * ring (after any "Turn off once") and whether a skip is waiting.
     */
    fun listJson(context: Context): String {
        val now = now()
        val out = JSONArray()
        for (a in AlarmStore.load(context)) {
            if (a.test) continue
            val o = a.toJson()
            o.remove("armedFor")
            o.remove("code")
            o.put("label", LabelStore.get(context, a.id))
            val next = AlarmSchedule.nextRing(a, now)
            if (next != null) o.put("nextRing", next.at.toInstant().toEpochMilli())
            o.put("skipActive", AlarmSchedule.skipActive(a, now))
            o.put("ringing", a.id == RingService.ringingId)
            out.put(o)
        }
        return out.toString()
    }

    /** Adds an alarm ([id] null) or changes one. A new or re-timed alarm is switched on. */
    fun save(
        context: Context,
        id: String?,
        hour: Int,
        minute: Int,
        days: Set<Int>,
        label: String,
        vibrate: Boolean,
        snoozeMinutes: Int,
    ): String {
        val now = now()
        val saved = AlarmStore.update(context) { list ->
            val i = if (id == null) -1 else list.indexOfFirst { it.id == id }
            if (i < 0) {
                val created = AlarmSchedule.withTime(
                    Alarm(
                        id = id ?: UUID.randomUUID().toString(),
                        code = (list.maxOfOrNull { it.code } ?: 0) + 1,
                        hour = hour,
                        minute = minute,
                        vibrate = vibrate,
                        snoozeMinutes = snoozeMinutes,
                        updatedAt = System.currentTimeMillis(),
                    ),
                    hour, minute, days, now,
                )
                list.add(created)
                created
            } else {
                val old = list[i]
                val timed = if (old.hour != hour || old.minute != minute || old.days != days) {
                    AlarmSchedule.withTime(old.copy(enabled = true), hour, minute, days, now)
                } else {
                    old
                }
                val changed = timed.copy(
                    vibrate = vibrate,
                    snoozeMinutes = snoozeMinutes,
                    updatedAt = editedAt(old),
                )
                list[i] = changed
                changed
            }
        }
        LabelStore.set(context, saved.id, label)
        AlarmNotifications.cancelSnoozed(context, saved.id)
        AlarmScheduler.rescheduleAll(context)
        return saved.id
    }

    fun setEnabled(context: Context, id: String, on: Boolean) = change(context, id) { a, now ->
        if (on) AlarmSchedule.turnOn(a, now) else AlarmSchedule.turnOff(a)
    }

    /** "Turn off once". */
    fun skipOnce(context: Context, id: String) = change(context, id) { a, now -> AlarmSchedule.skipOnce(a, now) }

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
        AlarmScheduler.rescheduleAll(context)
    }

    /**
     * Takes an alarm as the account's backup has it (another phone changed
     * it, or this phone is restoring). Only what syncs is taken; a snooze
     * on this phone stays unless the time changed or it is switched off.
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

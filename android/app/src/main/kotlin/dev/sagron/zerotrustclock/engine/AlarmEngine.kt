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
                    updatedAt = System.currentTimeMillis(),
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
                list.removeAt(i)
            }
        }
        LabelStore.remove(context, id)
        AlarmNotifications.cancelSnoozed(context, id)
        AlarmScheduler.rescheduleAll(context)
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

    private fun change(context: Context, id: String, how: (Alarm, ZonedDateTime) -> Alarm) {
        val now = now()
        AlarmStore.update(context) { list ->
            val i = list.indexOfFirst { it.id == id }
            if (i >= 0) {
                list[i] = how(list[i], now).copy(updatedAt = System.currentTimeMillis())
            }
        }
        AlarmNotifications.cancelSnoozed(context, id)
        AlarmScheduler.rescheduleAll(context)
    }
}

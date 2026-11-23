package dev.sagron.zerotrustclock.engine

import android.annotation.TargetApi
import android.content.Context
import android.content.pm.PackageManager
import android.health.connect.HealthConnectException
import android.health.connect.HealthConnectManager
import android.health.connect.InsertRecordsResponse
import android.health.connect.datatypes.Metadata
import android.health.connect.datatypes.Record
import android.health.connect.datatypes.SleepSessionRecord
import android.os.Build
import android.os.OutcomeReceiver
import android.os.UserManager
import dev.sagron.zerotrustclock.engine.core.SleepMath
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime
import org.json.JSONArray

/**
 * "Save sleep to Health Connect" (Bedtime, off unless switched on): each
 * night is written as a sleep session, from bedtime to when the wake-up
 * alarm was dismissed, or to the schedule's wake-up time when it did not
 * ring. It is the schedule, not a measurement, and is marked as entered
 * by hand. Other apps the user allows (ZT Fitness, ZT Quests) can read it.
 *
 * Android 14 and later only: Health Connect is part of Android there, so
 * nothing is added to the app. A night that can't be written yet (the
 * phone is locked, the permission is gone) waits and is tried again.
 */
object SleepLog {
    const val PERMISSION = "android.permission.health.WRITE_SLEEP"
    private const val KEY_QUEUE = "sleepQueue"
    private const val KEY_ACTUAL = "sleepActualFor"
    private const val MAX_WAITING = 14

    private fun prefs(context: Context) =
        AlarmStore.deviceContext(context).getSharedPreferences("bedtime", Context.MODE_PRIVATE)

    /** Health Connect is on this phone. */
    fun available(context: Context): Boolean =
        Build.VERSION.SDK_INT >= 34 && Api34.manager(context) != null

    /** The user let the app write sleep. */
    fun allowed(context: Context): Boolean =
        available(context) && context.checkSelfPermission(PERMISSION) == PackageManager.PERMISSION_GRANTED

    /**
     * The alarm [alarmId] was dismissed. When it is the bedtime's wake-up
     * alarm, last night is saved as ending now.
     */
    fun onAlarmDismissed(context: Context, alarmId: String) {
        val bedtime = BedtimeEngine.load(context)
        if (!bedtime.saveSleep || bedtime.wakeAlarmId != alarmId) return
        val now = ZonedDateTime.now(ZoneId.systemDefault())
        val start = bedtime.lastNight(now)?.first?.toInstant()?.toEpochMilli() ?: return
        val night = SleepMath.session(start, now.toInstant().toEpochMilli()) ?: return
        // The scheduled end, if it comes later, must not replace this.
        prefs(context).edit().putLong(KEY_ACTUAL, start).apply()
        add(context, night.first, night.second)
    }

    /**
     * The schedule's night is over. Saved with the schedule's wake-up
     * time, unless the wake-up alarm already told when it really ended.
     */
    fun onNightEnded(context: Context) {
        val bedtime = BedtimeEngine.load(context)
        if (!bedtime.saveSleep) return
        val now = ZonedDateTime.now(ZoneId.systemDefault())
        val last = bedtime.lastNight(now) ?: return
        val start = last.first.toInstant().toEpochMilli()
        val end = last.second.toInstant().toEpochMilli()
        // Called a little early or for a night still going: not yet.
        if (end > now.toInstant().toEpochMilli() + 60_000L) return
        if (prefs(context).getLong(KEY_ACTUAL, 0) == start) return
        val night = SleepMath.session(start, end) ?: return
        add(context, night.first, night.second)
    }

    private fun waiting(context: Context): MutableList<Pair<Long, Long>> {
        val out = mutableListOf<Pair<Long, Long>>()
        try {
            val a = JSONArray(prefs(context).getString(KEY_QUEUE, "[]"))
            for (i in 0 until a.length()) {
                val pair = a.getJSONArray(i)
                out.add(pair.getLong(0) to pair.getLong(1))
            }
        } catch (_: Exception) {
        }
        return out
    }

    private fun keep(context: Context, nights: List<Pair<Long, Long>>) {
        val a = JSONArray()
        nights.takeLast(MAX_WAITING).forEach { a.put(JSONArray().put(it.first).put(it.second)) }
        prefs(context).edit().putString(KEY_QUEUE, a.toString()).apply()
    }

    private fun add(context: Context, start: Long, end: Long) {
        synchronized(this) {
            // One entry a night: a later end replaces an earlier one.
            keep(context, waiting(context).filter { it.first != start } + (start to end))
        }
        flush(context)
    }

    /** Writes the nights that wait. Safe to call at any time. */
    fun flush(context: Context) {
        if (Build.VERSION.SDK_INT < 34) return
        val nights = synchronized(this) { waiting(context) }
        if (nights.isEmpty()) return
        // Health Connect is closed until the first unlock after a restart.
        if (context.getSystemService(UserManager::class.java)?.isUserUnlocked != true) return
        if (!allowed(context)) return
        try {
            Api34.insert(context.applicationContext, nights) { ok ->
                if (ok) {
                    synchronized(this) {
                        // Nights added meanwhile stay.
                        keep(context, waiting(context).filter { it !in nights })
                    }
                }
            }
        } catch (_: Exception) {
            // Tried again with the next night, or when the app opens.
        }
    }

    /** Health Connect as Android 14 has it. Only touched there. */
    @TargetApi(34)
    private object Api34 {
        fun manager(context: Context): HealthConnectManager? = try {
            context.getSystemService(HealthConnectManager::class.java)
        } catch (_: Throwable) {
            null
        }

        fun insert(context: Context, nights: List<Pair<Long, Long>>, done: (Boolean) -> Unit) {
            val health = manager(context) ?: return done(false)
            val zone = ZoneId.systemDefault()
            val records: List<Record> = nights.map { (startMs, endMs) ->
                val start = Instant.ofEpochMilli(startMs)
                val end = Instant.ofEpochMilli(endMs)
                SleepSessionRecord.Builder(
                    Metadata.Builder()
                        // The same night written again replaces itself.
                        .setClientRecordId("ztclock-night-$startMs")
                        .setClientRecordVersion(endMs)
                        .setRecordingMethod(Metadata.RECORDING_METHOD_MANUAL_ENTRY)
                        .build(),
                    start,
                    end,
                )
                    .setStartZoneOffset(zone.rules.getOffset(start))
                    .setEndZoneOffset(zone.rules.getOffset(end))
                    .build()
            }
            health.insertRecords(
                records,
                context.mainExecutor,
                object : OutcomeReceiver<InsertRecordsResponse, HealthConnectException> {
                    override fun onResult(result: InsertRecordsResponse) = done(true)

                    override fun onError(error: HealthConnectException) = done(false)
                },
            )
        }
    }
}

package dev.sagron.zerotrustclock.engine

import android.content.Context
import android.content.SharedPreferences
import android.os.UserManager
import android.util.AtomicFile
import dev.sagron.zerotrustclock.engine.core.Alarm
import java.io.File
import java.io.FileNotFoundException

/**
 * The alarms, kept in device-protected storage: Android can read it
 * before the phone's first unlock after a restart, which is when a
 * GrapheneOS phone that restarted itself overnight has to ring.
 *
 * It holds only what is needed to ring. Labels are in [LabelStore].
 */
object AlarmStore {
    private val lock = Any()
    private const val FILE = "alarms.json"

    /** Storage that is readable before the first unlock. */
    fun deviceContext(context: Context): Context =
        if (context.isDeviceProtectedStorage) context else context.createDeviceProtectedStorageContext()

    private fun file(context: Context) = AtomicFile(File(deviceContext(context).filesDir, FILE))

    fun load(context: Context): List<Alarm> = synchronized(lock) { read(context) }

    /** Reads, changes and writes in one step, so two changes never overlap. */
    fun <T> update(context: Context, change: (MutableList<Alarm>) -> T): T = synchronized(lock) {
        val list = read(context).toMutableList()
        val before = Alarm.listToJson(list)
        val result = change(list)
        val after = Alarm.listToJson(list)
        if (after != before) write(context, after)
        result
    }

    private fun read(context: Context): List<Alarm> {
        val text = try {
            String(file(context).readFully(), Charsets.UTF_8)
        } catch (_: FileNotFoundException) {
            return emptyList()
        } catch (_: Exception) {
            return emptyList()
        }
        return try {
            Alarm.listFromJson(text)
        } catch (_: Exception) {
            // Unreadable as a whole: keep a copy for a later look, start empty.
            try {
                File(deviceContext(context).filesDir, "$FILE.bad").writeText(text)
            } catch (_: Exception) {
            }
            emptyList()
        }
    }

    private fun write(context: Context, json: String) {
        val f = file(context)
        val out = f.startWrite()
        try {
            out.write(json.toByteArray(Charsets.UTF_8))
            f.finishWrite(out)
        } catch (e: Exception) {
            f.failWrite(out)
            throw e
        }
    }
}

/**
 * Alarm labels. They can be private ("Take the pill"), so they stay in
 * the normal, unlock-protected storage: before the first unlock an alarm
 * rings without its label.
 */
object LabelStore {
    private fun prefs(context: Context): SharedPreferences? {
        val users = context.getSystemService(UserManager::class.java)
        if (users?.isUserUnlocked != true) return null
        return try {
            context.applicationContext.getSharedPreferences("alarm_labels", Context.MODE_PRIVATE)
        } catch (_: Exception) {
            null
        }
    }

    fun get(context: Context, id: String): String = prefs(context)?.getString(id, "") ?: ""

    fun set(context: Context, id: String, label: String) {
        val p = prefs(context) ?: return
        if (label.isBlank()) p.edit().remove(id).apply() else p.edit().putString(id, label.trim()).apply()
    }

    fun remove(context: Context, id: String) {
        prefs(context)?.edit()?.remove(id)?.apply()
    }
}

/** Small engine settings, readable before the first unlock. */
object EnginePrefs {
    private fun prefs(context: Context): SharedPreferences =
        AlarmStore.deviceContext(context).getSharedPreferences("engine", Context.MODE_PRIVATE)

    /** The app's language ("en", "he"), or null to follow the phone. */
    fun language(context: Context): String? = prefs(context).getString("lang", null)

    fun setLanguage(context: Context, code: String?) {
        prefs(context).edit().apply { if (code == null) remove("lang") else putString("lang", code) }.apply()
    }

    /** When alarms were last set again after a restart, and whether the phone was still locked. */
    fun recordBoot(context: Context, atMs: Long, beforeUnlock: Boolean) {
        prefs(context).edit().putLong("bootAt", atMs).putBoolean("bootLocked", beforeUnlock).apply()
    }

    fun bootAt(context: Context): Long = prefs(context).getLong("bootAt", 0)

    fun bootLocked(context: Context): Boolean = prefs(context).getBoolean("bootLocked", false)
}

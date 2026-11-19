package dev.sagron.zerotrustclock.engine

import android.content.Context
import android.icu.text.TimeZoneNames
import android.icu.util.TimeZone
import android.icu.util.ULocale
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.ZoneId
import java.util.Locale

/**
 * The world clock's cities: every time zone Android knows, named by its
 * main city in the app's language (Android's own translations, so it
 * works offline and needs no list of our own).
 */
object WorldZones {
    private fun locale(context: Context): Locale =
        EnginePrefs.language(context)?.let { Locale.forLanguageTag(it) } ?: Locale.getDefault()

    /** Every city: id, city, country and its offset from UTC now (minutes). */
    fun allJson(context: Context): String {
        val locale = locale(context)
        val names = TimeZoneNames.getInstance(ULocale.forLocale(locale))
        val now = Instant.now()
        val out = JSONArray()
        val ids = TimeZone.getAvailableIDs(TimeZone.SystemTimeZoneType.CANONICAL_LOCATION, null, null)
        for (id in ids) {
            val city = names.getExemplarLocationName(id) ?: continue
            val zone = try {
                ZoneId.of(id)
            } catch (_: Exception) {
                continue
            }
            out.put(
                JSONObject()
                    .put("id", id)
                    .put("city", city)
                    .put("country", country(id, locale))
                    .put("offset", zone.rules.getOffset(now).totalSeconds / 60),
            )
        }
        return out.toString()
    }

    /** The offsets from UTC now (minutes) of [ids]; unknown ids are left out. */
    fun offsets(ids: List<String>): Map<String, Int> {
        val now = Instant.now()
        val out = HashMap<String, Int>()
        for (id in ids) {
            try {
                out[id] = ZoneId.of(id).rules.getOffset(now).totalSeconds / 60
            } catch (_: Exception) {
            }
        }
        return out
    }

    /** The city names of [ids] in the app's language. */
    fun names(context: Context, ids: List<String>): Map<String, String> {
        val names = TimeZoneNames.getInstance(ULocale.forLocale(locale(context)))
        val out = HashMap<String, String>()
        for (id in ids) {
            try {
                names.getExemplarLocationName(id)?.let { out[id] = it }
            } catch (_: Exception) {
            }
        }
        return out
    }

    private fun country(id: String, locale: Locale): String = try {
        val region = TimeZone.getRegion(id)
        if (region == "001") "" else Locale("", region).getDisplayCountry(locale)
    } catch (_: Exception) {
        ""
    }

    /** The cities the user picked, oldest first, for the widgets. */
    fun saved(context: Context): List<String> {
        val text = AlarmStore.deviceContext(context)
            .getSharedPreferences("engine", Context.MODE_PRIVATE)
            .getString("worldCities", null) ?: return emptyList()
        return try {
            val a = JSONArray(text)
            (0 until a.length()).map { a.getString(it) }
        } catch (_: Exception) {
            emptyList()
        }
    }

    fun setSaved(context: Context, ids: List<String>) {
        AlarmStore.deviceContext(context)
            .getSharedPreferences("engine", Context.MODE_PRIVATE)
            .edit()
            .putString("worldCities", JSONArray(ids).toString())
            .apply()
        Widgets.refresh(context)
    }
}

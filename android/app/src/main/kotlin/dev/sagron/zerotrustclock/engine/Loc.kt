package dev.sagron.zerotrustclock.engine

import android.content.Context
import android.content.res.Configuration
import java.util.Locale

/**
 * The ring screen and notifications in the language picked in the app's
 * Settings (English or Hebrew), not the phone's.
 */
object Loc {
    fun wrap(context: Context): Context {
        val code = try {
            EnginePrefs.language(context)
        } catch (_: Exception) {
            null
        } ?: return context
        val config = Configuration(context.resources.configuration)
        config.setLocale(Locale.forLanguageTag(code))
        return context.createConfigurationContext(config)
    }
}

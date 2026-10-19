package com.plantapp

import android.content.Context
import android.content.res.Configuration
import java.util.Locale

/** The languages the app ships in. [tag] is the BCP-47 tag matching the res/values-* folder. */
enum class AppLanguage(val tag: String, val nativeName: String) {
    Arabic("ar", "العربية"),
    Kurdish("ckb", "کوردی"), // Central Kurdish (Sorani), Arabic script, right-to-left
    English("en", "English");

    companion object {
        private const val PREFS = "plantapp_prefs"
        private const val KEY = "language"

        /** The language the user explicitly picked, or null to follow the device language. */
        fun saved(context: Context): AppLanguage? {
            val tag = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null)
            return entries.firstOrNull { it.tag == tag }
        }

        fun save(context: Context, language: AppLanguage) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit().putString(KEY, language.tag).apply()
        }

        /** The language currently shown, derived from the active resources configuration. */
        fun current(context: Context): AppLanguage {
            val code = context.resources.configuration.locales[0].language
            return entries.firstOrNull { it.tag == code } ?: English
        }

        /** Wraps [base] so resources (and layout direction) use the saved language. */
        fun wrap(base: Context): Context {
            val chosen = saved(base) ?: return base
            val locale = Locale.forLanguageTag(chosen.tag)
            Locale.setDefault(locale)
            val config = Configuration(base.resources.configuration)
            config.setLocale(locale)
            config.setLayoutDirection(locale)
            return base.createConfigurationContext(config)
        }
    }
}

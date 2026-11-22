package dev.sagron.zerotrustclock.engine

import android.app.Activity
import android.content.Context
import android.os.Bundle
import android.view.View
import dev.sagron.zerotrustclock.R

/**
 * What the app does with Health Connect, shown when the user taps the
 * app's privacy link in Health Connect's permission screens. Android
 * needs every app that asks for a health permission to have this screen.
 */
class HealthInfoActivity : Activity() {
    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(Loc.wrap(base))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_health_info)
        findViewById<View>(R.id.health_close).setOnClickListener { finish() }
    }
}

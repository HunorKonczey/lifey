package com.khunor.lifey

import android.os.Bundle
import android.view.Gravity
import android.widget.TextView
import androidx.activity.ComponentActivity

/**
 * F0 spike UI (docs/40-watch-app-plan.md §5.1) — proves the wear module
 * builds and installs standalone. F3 replaces this with the Compose for
 * Wear OS `ActiveWorkoutScreen`/`IdleScreen` (docs/40-watch-app-plan.md §5.1).
 */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(
            TextView(this).apply {
                text = "Lifey\nIndíts edzést a telefonon"
                gravity = Gravity.CENTER
            }
        )
    }
}

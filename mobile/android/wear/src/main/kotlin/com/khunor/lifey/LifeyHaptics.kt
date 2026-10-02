package com.khunor.lifey

import android.content.Context
import android.os.VibrationEffect
import android.os.Vibrator

/**
 * The haptic map of the watch design system (frame 07, D-X0.14): one function per event, each wrapping the
 * existing waveform. Events and timing are unchanged by the redesign; the map only records which visual
 * each one accompanies. The rest vibration stays timed from `ExerciseService`'s own clock (`elapsedRealtime`),
 * independent of what is on screen.
 */
object LifeyHaptics {
    /** Set logged (60·80·60 ms double pulse) ↔ the "+1" circle turns success. */
    fun setLogged(context: Context) = vibrate(context, VibrationEffect.createWaveform(longArrayOf(0, 60, 80, 60), -1))

    /** Logging failed (one 400 ms pulse) ↔ the error pill (≈ 2.5 s). */
    fun logFailed(context: Context) = oneLongPulse(context)

    /** Rest over (one 400 ms pulse) ↔ the "Mehet!" ring. */
    fun restOver(context: Context) = oneLongPulse(context)

    /** Stepper ± / rotary detent (EFFECT_TICK) ↔ the number swaps. */
    fun stepperTick(context: Context) = vibrate(context, VibrationEffect.createPredefined(VibrationEffect.EFFECT_TICK))

    private fun oneLongPulse(context: Context) =
        vibrate(context, VibrationEffect.createOneShot(400, VibrationEffect.DEFAULT_AMPLITUDE))

    private fun vibrate(context: Context, effect: VibrationEffect) {
        context.getSystemService(Vibrator::class.java)?.vibrate(effect)
    }
}

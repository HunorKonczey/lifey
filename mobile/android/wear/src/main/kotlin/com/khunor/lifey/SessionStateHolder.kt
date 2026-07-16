package com.khunor.lifey

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update

enum class SessionPhase { IDLE, ACTIVE }

data class SessionMetadata(
    val sessionClientId: String? = null,
    val title: String? = null,
    val exerciseName: String? = null,
    val setsDone: Int? = null,
    val setsTotal: Int? = null,
)

data class LiveMetrics(
    val heartRateBpm: Double? = null,
    val activeCalories: Double? = null,
    val startedAtElapsedRealtimeMs: Long? = null,
)

/**
 * Process-wide state shared between [PhoneListenerService] (the phone's
 * "last known state" DataItem sync, docs/40-watch-app-plan.md §D2),
 * [ExerciseService] (live Health Services metrics, §5.3), and the Compose UI
 * (§5.1) — this is the single in-process source of truth all three read from
 * or write into.
 */
object SessionStateHolder {
    private val _phase = MutableStateFlow(SessionPhase.IDLE)
    val phase: StateFlow<SessionPhase> = _phase

    private val _metadata = MutableStateFlow(SessionMetadata())
    val metadata: StateFlow<SessionMetadata> = _metadata

    private val _liveMetrics = MutableStateFlow(LiveMetrics())
    val liveMetrics: StateFlow<LiveMetrics> = _liveMetrics

    /** Applied from the phone's synced state DataItem — never clears a field the new payload didn't include. */
    fun onStateSynced(
        sessionClientId: String,
        title: String?,
        exerciseName: String?,
        setsDone: Int?,
        setsTotal: Int?,
    ) {
        _metadata.update { current ->
            current.copy(
                sessionClientId = sessionClientId,
                title = title ?: current.title,
                exerciseName = exerciseName ?: current.exerciseName,
                setsDone = setsDone ?: current.setsDone,
                setsTotal = setsTotal ?: current.setsTotal,
            )
        }
    }

    fun onExerciseActive(startedAtElapsedRealtimeMs: Long) {
        _phase.value = SessionPhase.ACTIVE
        _liveMetrics.update { it.copy(startedAtElapsedRealtimeMs = startedAtElapsedRealtimeMs) }
    }

    fun onHeartRate(bpm: Double) {
        _liveMetrics.update { it.copy(heartRateBpm = bpm) }
    }

    fun onCalories(kcal: Double) {
        _liveMetrics.update { it.copy(activeCalories = kcal) }
    }

    /** Reset to idle once the exercise (and its notification) is fully torn down. */
    fun reset() {
        _phase.value = SessionPhase.IDLE
        _metadata.value = SessionMetadata()
        _liveMetrics.value = LiveMetrics()
    }
}

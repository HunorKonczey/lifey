package com.khunor.lifey.ui.active

import com.khunor.lifey.SessionMetadata
import com.khunor.lifey.StandaloneTemplate
import com.khunor.lifey.StandaloneTemplateExercise
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * LIF-129: in a phone-mastered session the main page described the plan's
 * *first* exercise whatever the user picked, because it read the standalone
 * position — which only a watch-started session ever moves.
 */
class PlanExerciseDisplayTest {
    private val bench = StandaloneTemplateExercise(
        exerciseId = "bench", name = "Bench Press", restSeconds = 90, targetSets = 3, setsDone = 0,
    )
    private val row = StandaloneTemplateExercise(
        exerciseId = "row", name = "Barbell Row", restSeconds = 90, targetSets = 4, setsDone = 1,
    )
    private val curl = StandaloneTemplateExercise(
        exerciseId = "curl", name = "Bicep Curl", restSeconds = 60, targetSets = null, setsDone = 2,
    )

    private fun phoneSession(
        phoneCurrent: String? = "bench",
        picked: String? = null,
    ) = SessionMetadata(
        sessionClientId = "s1",
        exerciseName = "Bench Press",
        setsDone = 0,
        setsTotal = 3,
        sessionPlanExercises = listOf(bench, row, curl),
        phoneCurrentExerciseId = phoneCurrent,
        phoneSelectedExerciseId = picked,
    )

    @Test
    fun phoneMasteredFollowsTheExerciseThePhoneNamed() {
        val display = planExerciseDisplay(phoneSession(phoneCurrent = "row"))!!

        assertEquals("Barbell Row", display.name)
        assertEquals(1, display.setsDone)
        assertEquals(4, display.setsTotal)
    }

    @Test
    fun aLocalPickWinsOverWhatThePhoneLastNamed() {
        // The case from the ticket: the list shows the new exercise ticked, the
        // phone is still pushing "bench", and the main page has to follow the
        // pick rather than keep describing Bench Press 0/3.
        val display = planExerciseDisplay(phoneSession(phoneCurrent = "bench", picked = "row"))!!

        assertEquals("Barbell Row", display.name)
        assertEquals(1, display.setsDone)
        assertEquals(4, display.setsTotal)
    }

    @Test
    fun anExerciseWithoutATargetShowsTheFreeFormatLine() {
        val display = planExerciseDisplay(phoneSession(phoneCurrent = "curl"))!!

        assertEquals("Bicep Curl", display.name)
        assertNull(display.setsTotal)
        assertEquals(2, display.freeFormatSets?.first)
    }

    @Test
    fun withoutAPlanTheCallerFallsBackToThePhonesOwnFields() {
        val noPlan = phoneSession().copy(sessionPlanExercises = null)

        assertNull(planExerciseDisplay(noPlan))
    }

    @Test
    fun anIdTheCurrentPlanDoesNotContainFallsBackToo() {
        // Deleted on the phone while picked here: nothing to describe, so the
        // phone's own exerciseName / counts are what the page shows.
        assertNull(planExerciseDisplay(phoneSession(phoneCurrent = "gone", picked = null)))
    }

    @Test
    fun beforeTheFirstPushThereIsNoCurrentExerciseYet() {
        assertNull(planExerciseDisplay(phoneSession(phoneCurrent = null)))
    }

    @Test
    fun aStandaloneSessionStillFollowsItsOwnPosition() {
        val template = StandaloneTemplate("t1", "Upper A", listOf(bench, row))
        val standalone = SessionMetadata(
            sessionClientId = "w1",
            isStandalone = true,
            standaloneTemplate = template,
            standaloneExerciseIndex = 1,
            // A stale phone-mastered id must not matter in a standalone session.
            phoneSelectedExerciseId = "bench",
        )

        val display = planExerciseDisplay(standalone)
        assertNotNull(display)
        assertEquals("Barbell Row", display!!.name)
    }

    @Test
    fun currentPlanIndexIsThePositionOfTheCurrentExercise() {
        assertEquals(1, phoneSession(phoneCurrent = "bench", picked = "row").currentPlanIndex)
        assertEquals(0, phoneSession(phoneCurrent = "bench").currentPlanIndex)
        assertNull(phoneSession(phoneCurrent = null).currentPlanIndex)
    }
}

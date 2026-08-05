package com.khunor.lifey

import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

/**
 * JSON ⇄ typed model for the two exercise lists a standalone session can work
 * against: the **synced template** it started from (docs/watch/
 * 49-watch-f6b-template-sync-plan.md §4.1) and the phone's **live session
 * plan** (docs/watch/50-watch-f6c-session-plan-sync-plan.md).
 *
 * They share a shape on purpose — one decoder, one round-trip, and everything
 * downstream ([SessionMetadata.activePlanExercises]) treats them identically —
 * and this object exists because both [ExerciseService] (recovery snapshot,
 * picker) and [PhoneListenerService] (state sync) need it. Mirrors iOS, where
 * both decode into `CachedTemplateExercise` through `JSONDecoder`.
 *
 * Every parse is failure-tolerant in the same way: a malformed payload is
 * `null`/empty — "carry on with what we already have" — never a half-applied
 * list.
 */
object StandalonePlanJson {
    private const val TAG = "LifeyStandalonePlan"

    /** The phone's live session plan, as it rides inside the session-state
     * payload: a JSON **string** (see `buildWatchSessionPlanJson`), because
     * the DataItem transport this state can arrive over carries only flat
     * values. Null when absent, unparseable, or empty — all of which mean
     * "keep using the cached template". */
    fun parseSessionPlan(json: String?): List<StandaloneTemplateExercise>? {
        if (json.isNullOrEmpty()) return null
        return try {
            val exercises = parseExercises(JSONObject(json).optJSONArray("exercises"))
            exercises.ifEmpty { null }
        } catch (e: Exception) {
            Log.w(TAG, "parseSessionPlan failed to parse payload", e)
            null
        }
    }

    fun parseExercises(array: JSONArray?): List<StandaloneTemplateExercise> {
        if (array == null) return emptyList()
        return (0 until array.length()).mapNotNull { i ->
            try {
                val exercise = array.getJSONObject(i)
                val previousArray = exercise.optJSONArray("previousSets") ?: JSONArray()
                StandaloneTemplateExercise(
                    exerciseId = exercise.getString("exerciseId"),
                    name = exercise.getString("name"),
                    restSeconds = exercise.getInt("restSeconds"),
                    targetSets = if (exercise.has("targetSets")) exercise.getInt("targetSets") else null,
                    setsDone = if (exercise.has("setsDone")) exercise.getInt("setsDone") else null,
                    previousSets = (0 until previousArray.length()).map { j ->
                        val previous = previousArray.getJSONObject(j)
                        StandalonePreviousSet(
                            weight = previous.getDouble("weight"),
                            reps = previous.getInt("reps"),
                        )
                    },
                )
            } catch (e: Exception) {
                // One malformed entry costs that entry, not the whole list —
                // same rule the set list already follows.
                Log.w(TAG, "skipping malformed plan exercise", e)
                null
            }
        }
    }

    /** The recovery-snapshot counterpart of [parseExercises]. */
    fun exercisesToJson(exercises: List<StandaloneTemplateExercise>): JSONArray =
        JSONArray().apply {
            exercises.forEach { exercise ->
                put(
                    JSONObject().apply {
                        put("exerciseId", exercise.exerciseId)
                        put("name", exercise.name)
                        put("restSeconds", exercise.restSeconds)
                        putOpt("targetSets", exercise.targetSets)
                        putOpt("setsDone", exercise.setsDone)
                        // Round-tripped too, or a session recovered after
                        // process death would lose its prefill and drop back
                        // to the bare default mid-workout.
                        put(
                            "previousSets",
                            JSONArray().apply {
                                exercise.previousSets.forEach { previous ->
                                    put(
                                        JSONObject().apply {
                                            put("weight", previous.weight)
                                            put("reps", previous.reps)
                                        },
                                    )
                                }
                            },
                        )
                    },
                )
            }
        }

    fun parseTemplate(json: String): StandaloneTemplate? {
        return try {
            val obj = JSONObject(json)
            StandaloneTemplate(
                templateId = obj.getString("templateId"),
                title = obj.getString("title"),
                exercises = parseExercises(obj.optJSONArray("exercises")),
            )
        } catch (e: Exception) {
            Log.w(TAG, "parseTemplate failed to parse payload", e)
            null
        }
    }

    fun templateToJson(template: StandaloneTemplate): JSONObject = JSONObject().apply {
        put("templateId", template.templateId)
        put("title", template.title)
        put("exercises", exercisesToJson(template.exercises))
    }
}

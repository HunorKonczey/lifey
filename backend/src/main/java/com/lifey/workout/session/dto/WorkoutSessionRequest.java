package com.lifey.workout.session.dto;

import com.lifey.workout.session.SessionKind;
import com.lifey.workout.session.cardio.ActivityType;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PastOrPresent;
import jakarta.validation.constraints.PositiveOrZero;

import java.time.Instant;
import java.util.List;

public record WorkoutSessionRequest(

        @NotNull
        @PastOrPresent
        Instant startedAt,

        @PastOrPresent
        Instant finishedAt,

        /*
         * Exercises planned for this session (e.g. resolved client-side from a
         * template's exerciseIds). May be empty for a session started from scratch.
         */
        @NotNull
        List<Long> exerciseIds,

        /*
         * Sets actually logged so far. May be empty — a session can be started
         * with no sets recorded yet and filled in as the workout progresses.
         */
        @NotNull
        List<@Valid ExerciseSetRequest> sets,

        /* Active energy burned (kcal), imported from Apple Health. */
        @PositiveOrZero
        Double activeCalories,

        /* Average heart rate (bpm) over the workout, imported from Apple Health. */
        @PositiveOrZero
        Double averageHeartRate,

        /* HKWorkout UUID this session was paired with, if imported from Apple Health. */
        String healthWorkoutId,

        /*
         * The template this session was started from, if any. Only read on
         * create — a session's template link doesn't change once it's started.
         */
        Long templateId,

        /* Difficulty rating (1-10, RPE-style), captured after finishing. Optional. */
        @Min(1)
        @Max(10)
        Integer rpe,

        /* Optional free-text note captured alongside rpe. */
        String feedbackNote,

        /*
         * The same planned exercises as exerciseIds, but each with the number of
         * sets the session plans for it. Optional and additive: a client that
         * doesn't send it (the web app, and any mobile build older than this
         * field) keeps working exactly as before, and a client that does send it
         * still sends exerciseIds too, so nothing has to guess which list is
         * authoritative — when this one is present it simply wins.
         *
         * Exists because targetSets used to live only in the mobile client's
         * local cache: the session came back from the server without it, and the
         * planned-but-not-yet-logged set rows vanished on every pull.
         */
        List<@Valid PlannedExerciseRequest> plannedExercises,

        /*
         * Null or STRENGTH from any client that predates cardio (docs/cardio/52
         * §3.2) — the server defaults it to STRENGTH, so an old client's
         * behaviour is unchanged.
         */
        SessionKind sessionKind,

        /*
         * Required exactly when sessionKind is CARDIO, rejected otherwise — a
         * cross-field rule the service checks (Bean Validation can't express
         * it), not this annotation set. See InvalidCardioRequestException.
         */
        ActivityType activityType,

        @PositiveOrZero
        Integer movingSeconds,

        /* Cardio metrics; must be null unless sessionKind is CARDIO. */
        @Valid
        CardioDetailsRequest cardio,

        /*
         * Per-km/lap splits, computed client-side (docs/cardio/54). Replaces
         * the whole list on update, same model as sets/plannedExercises. Must
         * be null or empty unless sessionKind is CARDIO.
         */
        List<@Valid CardioSplitRequest> splits,

        /*
         * Waypoints marked along a hike's route, computed client-side
         * (docs/cardio/60 C8.1). Same replace-the-whole-list model as splits;
         * must be null or empty unless sessionKind is CARDIO.
         */
        List<@Valid CardioWaypointRequest> waypoints
) {
}

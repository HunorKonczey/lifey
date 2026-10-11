package com.lifey.chat.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

import java.time.Instant;

/**
 * A result a participant shares in the thread — a finished workout, one
 * personal record or a meal (docs/chat/83-chat-result-card-plan.md, section 10).
 *
 * <p>A <em>snapshot</em>, frozen when it is sent: {@code sessionId} is only the
 * target of the recipient's tap, never a live reference. And a <em>claim</em>:
 * the service checks the shape and the bounds below, not the truth, so nothing
 * may count or rank these payloads (§2.3).
 *
 * <p>Exactly the sub-object matching {@link #kind} is present; the other is
 * null. That rule is cross-field, so it is enforced by {@code MessageCards},
 * not by an annotation here. Adding a kind means an enum value, a sub-object and
 * a branch there — no polymorphic type, because this module reads Jackson 2 and
 * 3 side by side and a type-info annotation read by both is a trap.
 *
 * @param sessionId  the workout session's id in the main API, or null when it had
 *                   not synced yet — the card is then complete but not tappable
 * @param occurredAt when the workout started / the record was set (UTC)
 */
public record MessageCard(
        @NotNull Kind kind,
        @Positive Long sessionId,
        @NotNull Instant occurredAt,
        @Valid Workout workout,
        @Valid Pr pr,
        @Valid Meal meal
) {

    /** A card without a meal - how every WORKOUT and PR card is built. */
    public MessageCard(Kind kind, Long sessionId, Instant occurredAt, Workout workout, Pr pr) {
        this(kind, sessionId, occurredAt, workout, pr, null);
    }

    public enum Kind {
        WORKOUT,
        PR,
        MEAL
    }

    /** The app's own meal types, by the names its API already uses. */
    public enum MealType {
        BREAKFAST,
        LUNCH,
        DINNER,
        SNACK
    }

    public enum WorkoutKind {
        STRENGTH,
        CARDIO
    }

    /** The app's own record types, by the names it already uses (docs/38). */
    public enum PrType {
        MAX_WEIGHT,
        REPS_AT_WEIGHT,
        ESTIMATED_ONE_RM
    }

    /**
     * @param title         the template or activity name; null for an unnamed session
     * @param volumeKg      Σ weight × reps of the done sets (strength)
     * @param distanceMeters the distance (cardio)
     * @param recordCount   how many personal records the session produced
     */
    public record Workout(
            @NotNull WorkoutKind workoutKind,
            @Size(max = 120) String title,
            @Min(0) @Max(604_800) Integer durationSeconds,
            @DecimalMin("0") @DecimalMax("10000000") Double volumeKg,
            @Min(0) @Max(10_000) Integer exerciseCount,
            @DecimalMin("0") @DecimalMax("1000000") Double distanceMeters,
            @Min(0) @Max(10_000) Integer recordCount
    ) {
    }

    /**
     * @param value         the new record: kg for {@code MAX_WEIGHT} and
     *                      {@code ESTIMATED_ONE_RM}, reps for {@code REPS_AT_WEIGHT}
     * @param previousValue the old record in the same unit; null for the first one
     * @param weightKg      weight of the set that earned it
     * @param reps          reps of the set that earned it
     */
    public record Pr(
            @NotNull @Size(min = 1, max = 120) String exerciseName,
            @NotNull PrType prType,
            @NotNull @DecimalMin("0") @DecimalMax("10000") Double value,
            @DecimalMin("0") @DecimalMax("10000") Double previousValue,
            @DecimalMin("0") @DecimalMax("10000") Double weightKg,
            @Min(0) @Max(10_000) Integer reps
    ) {
    }

    /**
     * One meal as the sender logged it (LIF-123): what they ate, in totals. Fibre and sugars are nullable on purpose - a food
     * with no figure is "not known", never 0 - and {@code fiberSugarPartial} says that only some of the foods had one, so the
     * reader takes them as a lower bound.
     *
     * @param itemCount the number of foods in the meal
     * @param itemNames up to three of their names, for a glance at what it was
     */
    public record Meal(
            @NotNull MealType mealType,
            @NotNull @DecimalMin("0") @DecimalMax("100000") Double calories,
            @NotNull @DecimalMin("0") @DecimalMax("10000") Double proteinGrams,
            @NotNull @DecimalMin("0") @DecimalMax("10000") Double carbsGrams,
            @NotNull @DecimalMin("0") @DecimalMax("10000") Double fatGrams,
            @DecimalMin("0") @DecimalMax("10000") Double fiberGrams,
            @DecimalMin("0") @DecimalMax("10000") Double sugarGrams,
            Boolean fiberSugarPartial,
            @Min(0) @Max(1_000) Integer itemCount,
            @Size(max = 3) java.util.List<@Size(max = 120) String> itemNames
    ) {
    }
}

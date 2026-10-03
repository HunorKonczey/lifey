package com.lifey.settings;

import java.time.Instant;
import java.util.Objects;

/**
 * Who changed a user's nutrition goals, and when - read off {@code user_settings.nutrition_goals_set_by/_at}.
 *
 * @param setByUserId the account that made the change; null when unknown or when that account was deleted
 */
public record NutritionGoalsAttribution(GoalsSource source, Instant setAt, Long setByUserId) {

    /** Nothing recorded. */
    public static NutritionGoalsAttribution unknown() {
        return new NutritionGoalsAttribution(GoalsSource.UNKNOWN, null, null);
    }

    /**
     * @param ownerId the user the goals belong to
     * @param setAt   when they last changed; null means the attribution was never recorded
     * @param setBy   who changed them; null with a non-null {@code setAt} means a deleted account, i.e. a trainer
     */
    public static NutritionGoalsAttribution of(Long ownerId, Instant setAt, Long setBy) {
        if (setAt == null) {
            return unknown();
        }
        GoalsSource source = setBy != null && setBy.equals(ownerId) ? GoalsSource.SELF : GoalsSource.TRAINER;
        return new NutritionGoalsAttribution(source, setAt, setBy);
    }

    /** True when any of the four nutrition goals differs; water and step goals are not nutrition goals. */
    public static boolean goalsDiffer(Integer calories0, Integer protein0, Integer carbs0, Integer fat0,
                                      Integer calories1, Integer protein1, Integer carbs1, Integer fat1) {
        return !Objects.equals(calories0, calories1)
                || !Objects.equals(protein0, protein1)
                || !Objects.equals(carbs0, carbs1)
                || !Objects.equals(fat0, fat1);
    }
}

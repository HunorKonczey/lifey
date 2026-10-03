package com.lifey.settings.service;

import com.lifey.settings.NutritionGoalsAttribution;
import com.lifey.settings.dto.NutritionGoalsSourceResponse;
import com.lifey.settings.dto.SettingsRequest;
import com.lifey.settings.dto.SettingsResponse;
import com.lifey.userdetails.dto.SuggestGoalsResponse;

public interface SettingsService {

    SettingsResponse get();

    SettingsResponse update(SettingsRequest request);

    /**
     * Applies recalculated daily calorie/macro/water goals (from
     * {@code com.lifey.userdetails.GoalCalculator}) to the current user's settings.
     * Called after a user-details edit changes biometrics/goal inputs.
     */
    SettingsResponse applyGoals(SuggestGoalsResponse goals);

    /**
     * Read-only lookup of another user's settings — used by the trainer
     * dashboard to show a client's nutrition goals (docs/personal_trainer/
     * 03-backend-terv.md).
     */
    SettingsResponse forUser(Long userId);

    /**
     * Sets another user's daily nutrition goals — used by the trainer's edit
     * endpoint (docs/32-trainer-nutrition-goals-plan.md, B2). A null field
     * clears that goal. Lazily creates the settings row like every other
     * write path. {@code actorId} is who is changing them (the trainer); it is recorded as the
     * goals' attribution only if a value actually changes.
     */
    SettingsResponse updateNutritionGoalsForUser(
            Long userId, Long actorId, Integer dailyCalorieGoal, Integer dailyProteinGoal,
            Integer dailyCarbsGoal, Integer dailyFatGoal);

    /**
     * Who last changed a user's nutrition goals and when (docs/redesign-web/82 section 2.4); {@code UNKNOWN} when it was
     * never recorded. Read-only, for any user: the caller has authorised {@code userId} first.
     */
    NutritionGoalsAttribution nutritionGoalsAttribution(Long userId);

    /** The same for the current user, with the trainer's display name resolved — what the client web shows. */
    NutritionGoalsSourceResponse nutritionGoalsSource();

    /**
     * Trainer-facing-only preference (docs/33-weekly-trainer-report-plan.md) —
     * deliberately outside {@link SettingsRequest}/{@link SettingsResponse}, so
     * it never rides the mobile settings round-trip. Both operate on the
     * current user (the trainer), lazily creating the settings row like every
     * other write path.
     */
    boolean isWeeklyReportEmailEnabled();

    boolean setWeeklyReportEmailEnabled(boolean enabled);
}

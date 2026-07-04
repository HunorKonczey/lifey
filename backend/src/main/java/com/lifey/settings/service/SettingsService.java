package com.lifey.settings.service;

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
}

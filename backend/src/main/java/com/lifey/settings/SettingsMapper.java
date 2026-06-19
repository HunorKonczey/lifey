package com.lifey.settings;

import com.lifey.settings.dto.SettingsRequest;
import com.lifey.settings.dto.SettingsResponse;

/**
 * Maps between {@link UserSettings} entities and settings DTOs.
 */
final class SettingsMapper {

    private SettingsMapper() {
    }

    static void applyRequest(UserSettings settings, SettingsRequest request) {
        settings.setUnitSystem(request.unitSystem());
        settings.setDailyCalorieGoal(request.dailyCalorieGoal());
        settings.setDailyProteinGoal(request.dailyProteinGoal());
        settings.setDailyCarbsGoal(request.dailyCarbsGoal());
        settings.setDailyFatGoal(request.dailyFatGoal());
        settings.setDailyWaterGoalLiters(request.dailyWaterGoalLiters());
        settings.setTheme(request.theme());
    }

    static SettingsResponse toResponse(UserSettings settings) {
        return new SettingsResponse(
                settings.getUnitSystem(),
                settings.getDailyCalorieGoal(),
                settings.getDailyProteinGoal(),
                settings.getDailyCarbsGoal(),
                settings.getDailyFatGoal(),
                settings.getDailyWaterGoalLiters(),
                settings.getTheme()
        );
    }
}

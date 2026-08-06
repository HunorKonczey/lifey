package com.lifey.settings;

import com.lifey.settings.dto.SettingsRequest;
import com.lifey.settings.dto.SettingsResponse;

/**
 * Maps between {@link UserSettings} entities and settings DTOs.
 */
public final class SettingsMapper {

    private SettingsMapper() {
    }

    public static void applyRequest(UserSettings settings, SettingsRequest request) {
        settings.setUnitSystem(request.unitSystem());
        settings.setDailyCalorieGoal(request.dailyCalorieGoal());
        settings.setDailyProteinGoal(request.dailyProteinGoal());
        settings.setDailyCarbsGoal(request.dailyCarbsGoal());
        settings.setDailyFatGoal(request.dailyFatGoal());
        settings.setDailyWaterGoalLiters(request.dailyWaterGoalLiters());
        settings.setDailyStepGoal(request.dailyStepGoal());
        settings.setTheme(request.theme());
        settings.setLanguage(request.language());
        settings.setWorkoutReminderEnabled(request.workoutReminderEnabled());
        settings.setTrainerCommentPushEnabled(request.trainerCommentPushEnabled());
        settings.setTrainerGoalsPushEnabled(request.trainerGoalsPushEnabled());
        settings.setProgramAssignedPushEnabled(request.programAssignedPushEnabled());
        // Absent (older client) means "don't touch it" — see SettingsRequest.
        if (request.chatPushEnabled() != null) {
            settings.setChatPushEnabled(request.chatPushEnabled());
        }
        // The flag, not the times, decides whether to write: it is what tells
        // "the client doesn't know about quiet hours" from "the user turned
        // them off", and only the second one should clear the stored window.
        if (Boolean.TRUE.equals(request.chatQuietHoursSet())) {
            settings.setChatQuietHoursStart(request.chatQuietHoursStart());
            settings.setChatQuietHoursEnd(request.chatQuietHoursEnd());
        } else if (Boolean.FALSE.equals(request.chatQuietHoursSet())) {
            settings.setChatQuietHoursStart(null);
            settings.setChatQuietHoursEnd(null);
        }
        settings.setRestTimerEnabled(request.restTimerEnabled());
        settings.setDefaultRestSeconds(request.defaultRestSeconds());
    }

    public static SettingsResponse toResponse(UserSettings settings) {
        return new SettingsResponse(
                settings.getUnitSystem(),
                settings.getDailyCalorieGoal(),
                settings.getDailyProteinGoal(),
                settings.getDailyCarbsGoal(),
                settings.getDailyFatGoal(),
                settings.getDailyWaterGoalLiters(),
                settings.getDailyStepGoal(),
                settings.getTheme(),
                settings.getLanguage(),
                settings.isWorkoutReminderEnabled(),
                settings.isTrainerCommentPushEnabled(),
                settings.isTrainerGoalsPushEnabled(),
                settings.isProgramAssignedPushEnabled(),
                settings.isChatPushEnabled(),
                settings.getChatQuietHoursStart(),
                settings.getChatQuietHoursEnd(),
                settings.isRestTimerEnabled(),
                settings.getDefaultRestSeconds()
        );
    }
}

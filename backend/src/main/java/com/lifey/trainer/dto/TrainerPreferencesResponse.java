package com.lifey.trainer.dto;

public record TrainerPreferencesResponse(
        boolean weeklyReportEmailEnabled,
        boolean clientMissedWorkoutPushEnabled,
        boolean clientWeighInPushEnabled
) {
}

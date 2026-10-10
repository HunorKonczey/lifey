package com.lifey.trainer.dto;

/**
 * Every field is optional: absent keeps the stored value, so a client that only knows the weekly report switch
 * (the first one) keeps working next to ones that send the push switches (docs/85-trainer-push-plan.md).
 */
public record TrainerPreferencesRequest(
        Boolean weeklyReportEmailEnabled,
        Boolean clientMissedWorkoutPushEnabled,
        Boolean clientWeighInPushEnabled
) {
}

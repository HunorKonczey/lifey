package com.lifey.trainer.dto;

import jakarta.validation.constraints.Positive;

/** A trainer sets a client's daily step goal (LIF-105). A null goal clears it; zero is not a goal. */
public record ClientStepGoalRequest(
        @Positive
        Integer dailyStepGoal
) {
}

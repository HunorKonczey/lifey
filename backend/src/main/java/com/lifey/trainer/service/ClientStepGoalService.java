package com.lifey.trainer.service;

import com.lifey.trainer.dto.ClientStepGoalRequest;
import com.lifey.trainer.dto.ClientStepGoalResponse;

public interface ClientStepGoalService {

    /**
     * Sets a client's daily step goal (LIF-105). A null goal clears it. The client is told by push only when the
     * value actually changed, and only if they have not turned trainer-goal pushes off — the same rule as the
     * nutrition goals ({@link ClientNutritionGoalsService}).
     */
    ClientStepGoalResponse updateStepGoal(Long trainerId, Long clientId, ClientStepGoalRequest request);
}

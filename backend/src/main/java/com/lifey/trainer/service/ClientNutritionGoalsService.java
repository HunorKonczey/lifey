package com.lifey.trainer.service;

import com.lifey.trainer.dto.ClientNutritionGoalsRequest;
import com.lifey.trainer.dto.ClientNutritionGoalsResponse;

public interface ClientNutritionGoalsService {

    /**
     * Sets a client's daily nutrition goals (docs/32-trainer-nutrition-goals-plan.md,
     * B2). Full replace of the four fields; a null field clears that goal.
     */
    ClientNutritionGoalsResponse updateGoals(Long trainerId, Long clientId, ClientNutritionGoalsRequest request);
}

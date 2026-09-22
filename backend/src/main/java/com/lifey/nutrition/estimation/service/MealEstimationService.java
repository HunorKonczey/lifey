package com.lifey.nutrition.estimation.service;

import com.lifey.nutrition.estimation.dto.MealEstimateResponse;
import org.springframework.web.multipart.MultipartFile;

/**
 * AI calorie estimation from a meal photo (docs/23-ai-calorie-estimation-plan.md
 * Phase 1). Online-only and stateless: nothing is persisted except the monthly
 * AI usage count; saving the result goes through the client's normal
 * offline-first meal flow.
 */
public interface MealEstimationService {

    MealEstimateResponse estimate(MultipartFile image);
}

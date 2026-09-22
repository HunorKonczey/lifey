package com.lifey.nutrition.estimation.dto;

import java.util.List;

/**
 * An empty {@code items} list is a normal answer — the photo showed no food —
 * and the client shows a friendly message. {@code notes} is an optional caveat
 * from the model, {@code null} when it had none.
 */
public record MealEstimateResponse(
        List<EstimatedItemResponse> items,
        String notes
) {
}

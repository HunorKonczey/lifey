package com.lifey.billing.dto;

import com.lifey.billing.entity.TrainerPlan;
import jakarta.validation.constraints.NotNull;

public record CheckoutSessionRequest(
        @NotNull TrainerPlan plan,
        @NotNull BillingInterval interval
) {
}

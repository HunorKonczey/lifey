package com.lifey.billing.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/**
 * {@code purchaseToken} is the StoreKit 2 signed {@code JWSTransaction} on
 * iOS; on Android (64 Prompt 9) it's the Play purchase token instead — one
 * shape, verified differently per platform (64 §6.1).
 */
public record StorePurchaseRequest(
        @NotNull StorePurchasePlatform platform,
        @NotBlank String productId,
        @NotBlank String purchaseToken
) {
}

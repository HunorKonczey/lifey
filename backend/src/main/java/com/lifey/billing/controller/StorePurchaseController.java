package com.lifey.billing.controller;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.billing.dto.EntitlementResponse;
import com.lifey.billing.dto.StorePurchaseRequest;
import com.lifey.billing.service.StoreBillingService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Any authenticated user, unlike {@code BillingCheckoutController}'s
 * {@code ROLE_TRAINER}-only endpoints on the same {@code /api/v1/billing}
 * prefix — mobile Pro is bought by individual users, not trainers
 * (docs/landing_page/64-billing-backend-plan.md §6.1).
 */
@Tag(name = "Store Purchases", description = "iOS/Android Pro purchase verification")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/billing")
public class StorePurchaseController {

    private final StoreBillingService storeBillingService;
    private final CurrentUserProvider currentUserProvider;

    @Operation(summary = "Verify a store purchase and link it to the current user")
    @PostMapping("/store-purchase")
    public EntitlementResponse verifyPurchase(@Valid @RequestBody StorePurchaseRequest request) {
        return storeBillingService.verifyPurchase(currentUserProvider.getUserId(), request);
    }
}

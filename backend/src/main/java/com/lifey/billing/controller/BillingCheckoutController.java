package com.lifey.billing.controller;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.billing.dto.CheckoutSessionRequest;
import com.lifey.billing.dto.CheckoutSessionResponse;
import com.lifey.billing.dto.PortalSessionResponse;
import com.lifey.billing.service.StripeBillingService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Both endpoints are {@code ROLE_TRAINER} (see {@code SecurityConfig}) and
 * return a URL the browser is redirected to (docs/landing_page/64-billing-backend-plan.md
 * §5.2). The success redirect is a UI convenience, not the source of truth —
 * the client polls {@code GET /api/v1/me/entitlements} after redirect since
 * the webhook (`64` Prompt 5) may land later (D-B5).
 */
@Tag(name = "Billing", description = "Stripe Checkout and billing-portal sessions for trainers")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/billing")
public class BillingCheckoutController {

    private final StripeBillingService stripeBillingService;
    private final CurrentUserProvider currentUserProvider;

    @Operation(summary = "Start a Stripe Checkout session for a trainer subscription")
    @PostMapping("/checkout-session")
    public CheckoutSessionResponse createCheckoutSession(@Valid @RequestBody CheckoutSessionRequest request) {
        String url = stripeBillingService.createCheckoutSession(
                currentUserProvider.getUserId(), request.plan(), request.interval());
        return new CheckoutSessionResponse(url);
    }

    @Operation(summary = "Open the Stripe billing portal for the current trainer")
    @PostMapping("/portal-session")
    public PortalSessionResponse createPortalSession() {
        String url = stripeBillingService.createPortalSession(currentUserProvider.getUserId());
        return new PortalSessionResponse(url);
    }
}

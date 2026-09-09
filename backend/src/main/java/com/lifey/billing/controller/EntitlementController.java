package com.lifey.billing.controller;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.billing.dto.EntitlementResponse;
import com.lifey.billing.service.EntitlementService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.CacheControl;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Duration;

/**
 * The one entitlement read every client uses (docs/landing_page/64-billing-backend-plan.md §3.1).
 * Never 404 — {@link EntitlementService#resolve} always returns a well-formed
 * response — and never 5xx for a business reason, since the resolver fails
 * open internally.
 */
@Tag(name = "Entitlements", description = "What tier/features the current user is entitled to")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/me/entitlements")
public class EntitlementController {

    private final EntitlementService entitlementService;
    private final CurrentUserProvider currentUserProvider;

    @Operation(summary = "Resolve the current user's entitlement")
    @GetMapping
    public ResponseEntity<EntitlementResponse> getEntitlement() {
        EntitlementResponse response = entitlementService.resolve(currentUserProvider.getUserId());
        return ResponseEntity.ok()
                .cacheControl(CacheControl.maxAge(Duration.ofSeconds(60)).cachePrivate())
                .body(response);
    }
}

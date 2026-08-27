package com.lifey.trainer.request.controller;

import com.lifey.trainer.request.dto.SuperAdminTrainerRequestResponse;
import com.lifey.trainer.request.service.TrainerRequestService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * The super-admin review queue for {@code trainer_request} rows
 * (docs/landing_page/66-trainer-billing-web-plan.md §2). {@code /api/v1/superadmin/**}
 * is already {@code ROLE_SUPER_ADMIN}-only in {@code SecurityConfig}, so no
 * further wiring is needed there.
 */
@Tag(name = "Super Admin", description = "Trainer access request queue")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/superadmin/trainer-requests")
public class SuperAdminTrainerRequestController {

    private final TrainerRequestService trainerRequestService;

    @Operation(summary = "List pending trainer access requests")
    @GetMapping
    public Page<SuperAdminTrainerRequestResponse> findPending(
            @PageableDefault(size = 50, sort = "createdAt") Pageable pageable) {
        return trainerRequestService.findPending(pageable);
    }

    @Operation(summary = "Approve a pending trainer access request",
            description = "Grants ROLE_TRAINER (starting the 14-day trial, 64 §4.1) and sends the approval email.")
    @PostMapping("/{id}/approve")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void approve(@PathVariable Long id) {
        trainerRequestService.approve(id);
    }

    @Operation(summary = "Reject a pending trainer access request")
    @PostMapping("/{id}/reject")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void reject(@PathVariable Long id) {
        trainerRequestService.reject(id);
    }
}

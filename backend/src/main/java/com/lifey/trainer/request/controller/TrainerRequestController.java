package com.lifey.trainer.request.controller;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.trainer.request.dto.TrainerRequestRequest;
import com.lifey.trainer.request.dto.TrainerRequestResponse;
import com.lifey.trainer.request.service.TrainerRequestService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * The landing page's "start free trial" CTA, made real (docs/landing_page/66-trainer-billing-web-plan.md
 * §2, D-T1) — any authenticated {@code ROLE_USER}, since role granting itself
 * stays a super-admin-only action.
 */
@Tag(name = "Trainer Requests", description = "Trainer access request flow (landing CTA -> super admin review)")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/trainer-requests")
public class TrainerRequestController {

    private final TrainerRequestService trainerRequestService;
    private final CurrentUserProvider currentUserProvider;

    @Operation(summary = "Submit a trainer access request",
            description = "One open (PENDING) request per user; 409 if one already exists or the user is already a trainer.")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public TrainerRequestResponse submit(@Valid @RequestBody TrainerRequestRequest request) {
        return trainerRequestService.submit(currentUserProvider.getUserId(), request);
    }

    @Operation(summary = "This user's most recent trainer access request",
            description = "Lets /admin/pending poll its own status. 404 if none was ever submitted.")
    @GetMapping("/me")
    public TrainerRequestResponse findMine() {
        return trainerRequestService.findMine(currentUserProvider.getUserId());
    }
}

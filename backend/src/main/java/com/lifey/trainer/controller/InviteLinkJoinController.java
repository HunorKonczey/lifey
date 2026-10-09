package com.lifey.trainer.controller;

import com.lifey.trainer.dto.InviteLinkPreviewResponse;
import com.lifey.trainer.service.TrainerInviteLinkService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * The visitor's side of a join link (LIF-103). The preview is public (the token is the credential, as with the emailed
 * accept link) so the landing page can say who is inviting before anyone signs in; taking the link needs an account.
 */
@Tag(name = "Trainer invite links")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/trainer-invite-links")
public class InviteLinkJoinController {

    private final TrainerInviteLinkService service;

    @Operation(summary = "Who is inviting - for the landing page of a join link",
            description = "Public. 404 for any link that is unknown, used, revoked or expired.")
    @GetMapping("/{token}")
    public InviteLinkPreviewResponse preview(@PathVariable String token) {
        return service.preview(token);
    }

    @Operation(summary = "Join the trainer who made this link",
            description = "Needs a signed-in account. 409 if you are already their client or they have no free seat; "
                    + "404 for a link that can no longer be used.")
    @PostMapping("/{token}/accept")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void accept(@PathVariable String token) {
        service.redeem(token);
    }
}

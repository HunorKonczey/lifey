package com.lifey.trainer.controller;

import com.lifey.trainer.exception.InviteNotFoundException;
import com.lifey.trainer.service.TrainerInviteService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Public, unauthenticated endpoint backing the accept/decline links in the
 * trainer invite email (see {@code TrainerInviteServiceImpl.invite} and
 * {@code SecurityConfig}'s public endpoints). The mobile app's in-app accept
 * flow ({@link ClientInviteController}) is unaffected — this is purely an
 * additional channel gated by {@code lifey.trainer-invite.email-enabled}.
 */
@Tag(name = "Trainer Invites (email)", description = "Public accept/decline links from the invite email")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/trainer-invites/email")
public class TrainerInviteEmailController {

    private final TrainerInviteService trainerInviteService;

    @Operation(summary = "Accept or decline a pending invite via its emailed token")
    @GetMapping(value = "/respond", produces = MediaType.TEXT_HTML_VALUE)
    public String respond(@RequestParam String token, @RequestParam boolean accept) {
        try {
            trainerInviteService.respondViaEmailToken(token, accept);
            return accept
                    ? page("Invite accepted", "You're now connected with your trainer. You can close this page and open the Lifey app.")
                    : page("Invite declined", "You declined the invite. You can close this page.");
        } catch (InviteNotFoundException _) {
            return page("Link no longer valid", "This invite link has expired or was already used.");
        }
    }

    private static String page(String title, String message) {
        return "<!DOCTYPE html><html><head><meta charset=\"UTF-8\"><title>" + title + "</title></head>"
                + "<body style=\"font-family: sans-serif; color: #222; text-align: center; padding-top: 80px;\">"
                + "<h2>" + title + "</h2><p>" + message + "</p></body></html>";
    }
}

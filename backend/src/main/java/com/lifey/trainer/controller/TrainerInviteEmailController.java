package com.lifey.trainer.controller;

import com.lifey.trainer.exception.InviteNotFoundException;
import com.lifey.trainer.service.TrainerInviteService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Public, unauthenticated endpoint backing the accept/decline links in the
 * trainer invite email (see {@code TrainerInviteServiceImpl.invite} and
 * {@code SecurityConfig}'s public endpoints). The mobile app's in-app accept
 * flow ({@link ClientInviteController}) is unaffected — this is purely an
 * additional channel gated by {@code lifey.trainer-invite.email-enabled}.
 *
 * <p>Two steps on purpose. The link in the email is a plain GET, and mail
 * security scanners (Safe Links and the like) and link previews open every
 * link in a message before the person does — so a GET that answered the invite
 * accepted or declined it for them, usually the first link in the mail whichever
 * they would have chosen. The GET therefore only shows a confirmation page; the
 * answer is recorded by the POST that page's button sends.
 */
@Tag(name = "Trainer Invites (email)", description = "Public accept/decline links from the invite email")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/trainer-invites/email")
public class TrainerInviteEmailController {

    private final TrainerInviteService trainerInviteService;

    @Operation(summary = "The confirmation page behind an invite email's link — changes nothing")
    @GetMapping(value = "/respond", produces = MediaType.TEXT_HTML_VALUE)
    public String confirm(@RequestParam String token, @RequestParam boolean accept) {
        return accept
                ? confirmationPage("Accept the invite?", "Confirm that you want to be this trainer's client on Lifey.",
                        "Accept invite")
                : confirmationPage("Decline the invite?", "Confirm that you do not want to be this trainer's client.",
                        "Decline invite");
    }

    @Operation(summary = "Accept or decline a pending invite via its emailed token")
    @PostMapping(value = "/respond", produces = MediaType.TEXT_HTML_VALUE)
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

    /**
     * The button posts to the page's own URL, query string included — the token and the choice are already
     * in it, so the form carries no fields (and the token is never written into the page).
     */
    private static String confirmationPage(String title, String message, String button) {
        return page(title, message
                + "</p><form method=\"post\"><button type=\"submit\" style=\"padding: 10px 20px; font-size: 16px;\">"
                + button + "</button></form><p>");
    }

    private static String page(String title, String message) {
        return "<!DOCTYPE html><html><head><meta charset=\"UTF-8\"><title>" + title + "</title></head>"
                + "<body style=\"font-family: sans-serif; color: #222; text-align: center; padding-top: 80px;\">"
                + "<h2>" + title + "</h2><p>" + message + "</p></body></html>";
    }
}

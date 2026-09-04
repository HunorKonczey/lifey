package com.lifey.contact;

import com.lifey.mail.MailLanguage;
import com.lifey.mail.service.MailService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * The marketing site's contact form (docs/landing_page/65 Prompt 8, 68 §6:
 * "a short form... plus a direct email address"). Public — no account
 * exists for an anonymous visitor to authenticate as (see SecurityConfig's
 * PUBLIC_ENDPOINTS) — same trust level as {@code /auth/register}, which
 * also has no rate limiting of its own; not adding one here either rather
 * than inventing a bespoke abuse-prevention story for one form.
 */
@Tag(name = "Contact", description = "Public marketing-site contact form")
@RestController
@RequestMapping("/api/v1/contact")
public class ContactController {

    private final MailService mailService;

    ContactController(MailService mailService) {
        this.mailService = mailService;
    }

    @Operation(summary = "Submit the public contact form", description = "Delivers to the team inbox; no response body.")
    @PostMapping
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void submit(@Valid @RequestBody ContactRequest request) {
        MailLanguage language = "hu".equals(request.locale()) ? MailLanguage.HU : MailLanguage.EN;
        mailService.sendContactMessage(request.name(), request.email(), request.message(), language);
    }
}

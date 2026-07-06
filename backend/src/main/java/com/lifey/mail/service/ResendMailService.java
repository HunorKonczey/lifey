package com.lifey.mail.service;

import com.lifey.mail.*;
import com.lifey.user.User;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.util.Map;

/**
 * Sends mail through the Resend HTTPS API (https://api.resend.com/emails), or
 * just logs when {@code lifey.mail.enabled=false} (default without a
 * {@code RESEND_API_KEY}). Used instead of SMTP because PaaS hosts like
 * Railway commonly block outbound SMTP ports; the Resend API goes over 443.
 * Every send runs on the {@code mailTaskExecutor} (see {@link MailConfig})
 * and failures are caught here so a bounced email never fails the request
 * that triggered it.
 */
@Service
class ResendMailService implements MailService {

    private static final Logger log = LoggerFactory.getLogger(ResendMailService.class);
    private static final String RESEND_API_URL = "https://api.resend.com/emails";

    private final RestClient restClient;
    private final MailProperties mailProperties;
    private final MailTemplateRenderer templateRenderer;
    private final MailLanguageResolver languageResolver;

    ResendMailService(MailProperties mailProperties, MailTemplateRenderer templateRenderer,
                      MailLanguageResolver languageResolver) {
        this.restClient = RestClient.create();
        this.mailProperties = mailProperties;
        this.templateRenderer = templateRenderer;
        this.languageResolver = languageResolver;
    }

    @Override
    @Async("mailTaskExecutor")
    public void sendWelcomeEmail(User user) {
        MailLanguage language = languageResolver.resolve(user);
        Map<String, String> placeholders = Map.of("name", displayName(user));
        String subject = language == MailLanguage.HU ? "Üdvözlünk a Lifey-ban 🎉" : "Welcome to Lifey 🎉";
        send(user, "welcome", "welcome", language, subject, placeholders);
    }

    @Override
    @Async("mailTaskExecutor")
    public void sendPasswordResetEmail(User user, String code) {
        MailLanguage language = languageResolver.resolve(user);
        Map<String, String> placeholders = Map.of("name", displayName(user), "code", code);
        String subject = language == MailLanguage.HU ? "Lifey jelszó-visszaállító kódod" : "Your Lifey password reset code";
        send(user, "password_reset", "password-reset", language, subject, placeholders);
    }

    @Override
    @Async("mailTaskExecutor")
    public void sendTrainerInviteEmail(User client, User trainer, String acceptUrl, String declineUrl) {
        MailLanguage language = languageResolver.resolve(client);
        String trainerName = displayName(trainer);
        Map<String, String> placeholders = Map.of(
                "name", displayName(client),
                "trainerName", trainerName,
                "acceptUrl", acceptUrl,
                "declineUrl", declineUrl
        );
        String subject = language == MailLanguage.HU
                ? trainerName + " meghívott, hogy legyél az ügyfele a Lifey-ban"
                : trainerName + " invited you to be their client on Lifey";
        send(client, "trainer_invite", "trainer-invite", language, subject, placeholders);
    }

    private void send(User user, String templateName, String mailType, MailLanguage language, String subject,
                      Map<String, String> placeholders) {
        if (!mailProperties.enabled()) {
            log.info("Mail disabled, would have sent '{}' email to {} ({})", mailType, user.getEmail(), language);
            return;
        }
        try {
            String html = templateRenderer.renderHtml(templateName, language, placeholders);
            String text = templateRenderer.renderText(templateName, language, placeholders);

            Map<String, Object> body = Map.of(
                    "from", mailProperties.from(),
                    "to", user.getEmail(),
                    "subject", subject,
                    "html", html,
                    "text", text
            );

            restClient.post()
                    .uri(RESEND_API_URL)
                    .header("Authorization", "Bearer " + mailProperties.resendApiKey())
                    .contentType(org.springframework.http.MediaType.APPLICATION_JSON)
                    .body(body)
                    .retrieve()
                    .toBodilessEntity();
        } catch (RuntimeException e) {
            log.error("Failed to send '{}' email to {}", mailType, user.getEmail(), e);
        }
    }

    private static String displayName(User user) {
        String email = user.getEmail();
        int at = email.indexOf('@');
        return at > 0 ? email.substring(0, at) : email;
    }
}

package com.lifey.mail.service;

import com.lifey.mail.*;
import com.lifey.user.User;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.time.format.DateTimeFormatter;
import java.util.Locale;
import java.util.Map;
import java.util.stream.Collectors;

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
    private static final DateTimeFormatter DATE_FORMAT = DateTimeFormatter.ofPattern("dd MMM", Locale.ENGLISH);

    private final RestClient restClient;
    private final MailProperties mailProperties;
    private final MailTemplateRenderer templateRenderer;
    private final MailLanguageResolver languageResolver;
    private final MailMessages messages;
    private final WeeklyReportFormatting weeklyReportFormatting;

    ResendMailService(MailProperties mailProperties, MailTemplateRenderer templateRenderer,
                      MailLanguageResolver languageResolver, MailMessages messages,
                      WeeklyReportFormatting weeklyReportFormatting) {
        this.restClient = RestClient.create();
        this.mailProperties = mailProperties;
        this.templateRenderer = templateRenderer;
        this.languageResolver = languageResolver;
        this.messages = messages;
        this.weeklyReportFormatting = weeklyReportFormatting;
    }

    @Override
    @Async("mailTaskExecutor")
    public void sendWelcomeEmail(User user) {
        MailLanguage language = languageResolver.resolve(user);
        Map<String, String> placeholders = Map.of("name", displayName(user));
        String subject = messages.get("mail.welcome.subject", language);
        send(user, "welcome", "welcome", language, subject, placeholders);
    }

    @Override
    @Async("mailTaskExecutor")
    public void sendPasswordResetEmail(User user, String code) {
        MailLanguage language = languageResolver.resolve(user);
        Map<String, String> placeholders = Map.of("name", displayName(user), "code", code);
        String subject = messages.get("mail.password-reset.subject", language);
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
        String subject = messages.get("mail.trainer-invite.subject", language, trainerName);
        send(client, "trainer_invite", "trainer-invite", language, subject, placeholders);
    }

    @Override
    @Async("mailTaskExecutor")
    public void sendWeeklyTrainerReport(User trainer, WeeklyTrainerReport report) {
        MailLanguage language = languageResolver.resolve(trainer);

        String clientRowsHtml = report.clients().stream()
                .map(c -> renderRow(c, language, true))
                .collect(Collectors.joining());
        String clientRowsText = report.clients().stream()
                .map(c -> renderRow(c, language, false))
                .collect(Collectors.joining());

        String weekStart = DATE_FORMAT.format(report.weekStart());
        String weekEnd = DATE_FORMAT.format(report.weekEnd());
        String subject = messages.get("mail.weekly-report.subject", language, weekStart, weekEnd);

        Map<String, String> htmlPlaceholders = Map.of("weekStart", weekStart, "weekEnd", weekEnd, "clientRows", clientRowsHtml);
        Map<String, String> textPlaceholders = Map.of("weekStart", weekStart, "weekEnd", weekEnd, "clientRows", clientRowsText);
        send(trainer, "weekly_report", "weekly_report", language, subject, htmlPlaceholders, textPlaceholders);
    }

    private String renderRow(WeeklyTrainerReport.ClientWeekSummary client, MailLanguage language, boolean html) {
        String summary = weeklyReportFormatting.summarize(client, language, html);
        String clientName = html ? WeeklyReportFormatting.escapeHtml(client.clientName()) : client.clientName();
        Map<String, String> placeholders = Map.of("clientName", clientName, "summary", summary);
        return html
                ? templateRenderer.renderHtml("weekly_report_row", language, placeholders)
                : templateRenderer.renderText("weekly_report_row", language, placeholders);
    }

    private void send(User user, String templateName, String mailType, MailLanguage language, String subject,
                      Map<String, String> placeholders) {
        send(user, templateName, mailType, language, subject, placeholders, placeholders);
    }

    private void send(User user, String templateName, String mailType, MailLanguage language, String subject,
                      Map<String, String> htmlPlaceholders, Map<String, String> textPlaceholders) {
        if (!mailProperties.enabled()) {
            log.info("Mail disabled, would have sent '{}' email to {} ({})", mailType, user.getEmail(), language);
            return;
        }
        try {
            String html = templateRenderer.renderHtml(templateName, language, htmlPlaceholders);
            String text = templateRenderer.renderText(templateName, language, textPlaceholders);

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

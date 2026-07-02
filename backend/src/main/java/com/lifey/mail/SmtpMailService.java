package com.lifey.mail;

import com.lifey.user.User;
import jakarta.mail.MessagingException;
import jakarta.mail.internet.MimeMessage;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.util.Map;

/**
 * Sends mail over the Gmail SMTP connection configured in application.yml, or
 * just logs when {@code app.mail.enabled=false} (default without a
 * {@code MAIL_PASSWORD}). Every send runs on the {@code mailTaskExecutor} (see
 * {@link MailConfig}) and failures are caught here so a bounced email never
 * fails the request that triggered it.
 */
@Service
class SmtpMailService implements MailService {

    private static final Logger log = LoggerFactory.getLogger(SmtpMailService.class);

    private final JavaMailSender mailSender;
    private final MailProperties mailProperties;
    private final MailTemplateRenderer templateRenderer;
    private final MailLanguageResolver languageResolver;

    SmtpMailService(JavaMailSender mailSender, MailProperties mailProperties,
                     MailTemplateRenderer templateRenderer, MailLanguageResolver languageResolver) {
        this.mailSender = mailSender;
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

    private void send(User user, String templateName, String mailType, MailLanguage language, String subject,
                       Map<String, String> placeholders) {
        if (!mailProperties.enabled()) {
            log.info("Mail disabled, would have sent '{}' email to {} ({})", mailType, user.getEmail(), language);
            return;
        }
        try {
            String html = templateRenderer.renderHtml(templateName, language, placeholders);
            String text = templateRenderer.renderText(templateName, language, placeholders);

            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");
            helper.setFrom(mailProperties.from());
            helper.setTo(user.getEmail());
            helper.setSubject(subject);
            helper.setText(text, html);

            mailSender.send(message);
        } catch (MessagingException | RuntimeException e) {
            log.error("Failed to send '{}' email to {}", mailType, user.getEmail(), e);
        }
    }

    private static String displayName(User user) {
        String email = user.getEmail();
        int at = email.indexOf('@');
        return at > 0 ? email.substring(0, at) : email;
    }
}

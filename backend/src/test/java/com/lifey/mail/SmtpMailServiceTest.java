package com.lifey.mail;

import com.lifey.settings.LanguagePreference;
import com.lifey.settings.UserSettings;
import com.lifey.settings.UserSettingsRepository;
import com.lifey.user.User;
import jakarta.mail.Session;
import jakarta.mail.internet.MimeMessage;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mail.javamail.JavaMailSender;

import java.util.Optional;
import java.util.Properties;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class SmtpMailServiceTest {

    @Mock
    JavaMailSender mailSender;

    @Mock
    UserSettingsRepository userSettingsRepository;

    private final MailTemplateRenderer templateRenderer = new MailTemplateRenderer();

    @Test
    void send_disabled_logsAndNeverTouchesMailSender() {
        MailProperties properties = new MailProperties("lifey@example.com", false);
        SmtpMailService service = new SmtpMailService(mailSender, properties, templateRenderer,
                new MailLanguageResolver(userSettingsRepository));

        service.sendWelcomeEmail(user(1L, "new@example.com"));

        verify(mailSender, never()).createMimeMessage();
        verify(mailSender, never()).send(any(MimeMessage.class));
    }

    @Test
    void send_enabled_sendsMimeMessageInUsersLanguage() {
        MailProperties properties = new MailProperties("lifey@example.com", true);
        SmtpMailService service = new SmtpMailService(mailSender, properties, templateRenderer,
                new MailLanguageResolver(userSettingsRepository));
        User user = user(1L, "new@example.com");
        UserSettings settings = new UserSettings();
        settings.setLanguage(LanguagePreference.HUNGARIAN);
        when(userSettingsRepository.findByUserId(1L)).thenReturn(Optional.of(settings));
        when(mailSender.createMimeMessage()).thenAnswer(inv -> new MimeMessage(Session.getInstance(new Properties())));

        service.sendPasswordResetEmail(user, "123456");

        verify(mailSender).send(any(MimeMessage.class));
    }

    @Test
    void send_mailSenderThrows_isCaughtAndNotPropagated() {
        MailProperties properties = new MailProperties("lifey@example.com", true);
        SmtpMailService service = new SmtpMailService(mailSender, properties, templateRenderer,
                new MailLanguageResolver(userSettingsRepository));
        when(userSettingsRepository.findByUserId(1L)).thenReturn(Optional.empty());
        when(mailSender.createMimeMessage()).thenAnswer(inv -> new MimeMessage(Session.getInstance(new Properties())));
        org.mockito.Mockito.doThrow(new org.springframework.mail.MailSendException("boom"))
                .when(mailSender).send(any(MimeMessage.class));

        assertThatCode(() -> service.sendWelcomeEmail(user(1L, "new@example.com")))
                .doesNotThrowAnyException();
    }

    private static User user(Long id, String email) {
        User user = new User();
        user.setId(id);
        user.setEmail(email);
        return user;
    }
}

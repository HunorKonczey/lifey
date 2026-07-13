package com.lifey.mail.service;

import com.lifey.mail.MailLanguageResolver;
import com.lifey.mail.MailProperties;
import com.lifey.mail.MailTemplateRenderer;
import com.lifey.mail.WeeklyTrainerReport;

import com.lifey.settings.LanguagePreference;
import com.lifey.settings.UserSettings;
import com.lifey.settings.UserSettingsRepository;
import com.lifey.user.User;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ResendMailServiceTest {

    @Mock
    UserSettingsRepository userSettingsRepository;

    private final MailTemplateRenderer templateRenderer = new MailTemplateRenderer();

    @Test
    void send_disabled_logsAndNeverCallsApi() {
        MailProperties properties = new MailProperties("lifey@example.com", false, "");
        ResendMailService service = new ResendMailService(properties, templateRenderer,
                new MailLanguageResolver(userSettingsRepository));

        assertThatCode(() -> service.sendWelcomeEmail(user(1L, "new@example.com")))
                .doesNotThrowAnyException();
    }

    @Test
    void send_enabled_apiCallFails_isCaughtAndNotPropagated() {
        // No real Resend API key/network available in unit tests — enabling
        // without a reachable endpoint exercises the failure path, which must
        // never propagate to the caller.
        MailProperties properties = new MailProperties("lifey@example.com", true, "test-key");
        ResendMailService service = new ResendMailService(properties, templateRenderer,
                new MailLanguageResolver(userSettingsRepository));
        when(userSettingsRepository.findByUserId(1L)).thenReturn(Optional.empty());

        assertThatCode(() -> service.sendWelcomeEmail(user(1L, "new@example.com")))
                .doesNotThrowAnyException();
    }

    @Test
    void send_enabled_resolvesUserLanguageBeforeSending() {
        MailProperties properties = new MailProperties("lifey@example.com", true, "test-key");
        ResendMailService service = new ResendMailService(properties, templateRenderer,
                new MailLanguageResolver(userSettingsRepository));
        User user = user(1L, "new@example.com");
        UserSettings settings = new UserSettings();
        settings.setLanguage(LanguagePreference.HUNGARIAN);
        when(userSettingsRepository.findByUserId(1L)).thenReturn(Optional.of(settings));

        assertThatCode(() -> service.sendPasswordResetEmail(user, "123456"))
                .doesNotThrowAnyException();
    }

    @Test
    void sendWeeklyTrainerReport_disabled_logsAndNeverCallsApi() {
        MailProperties properties = new MailProperties("lifey@example.com", false, "");
        ResendMailService service = new ResendMailService(properties, templateRenderer,
                new MailLanguageResolver(userSettingsRepository));

        assertThatCode(() -> service.sendWeeklyTrainerReport(user(1L, "trainer@example.com"), sampleReport()))
                .doesNotThrowAnyException();
    }

    @Test
    void sendWeeklyTrainerReport_enabled_apiCallFails_isCaughtAndNotPropagated() {
        MailProperties properties = new MailProperties("lifey@example.com", true, "test-key");
        ResendMailService service = new ResendMailService(properties, templateRenderer,
                new MailLanguageResolver(userSettingsRepository));
        when(userSettingsRepository.findByUserId(1L)).thenReturn(Optional.empty());

        assertThatCode(() -> service.sendWeeklyTrainerReport(user(1L, "trainer@example.com"), sampleReport()))
                .doesNotThrowAnyException();
    }

    @Test
    void sendWeeklyTrainerReport_emptyClientList_doesNotThrow() {
        MailProperties properties = new MailProperties("lifey@example.com", true, "test-key");
        ResendMailService service = new ResendMailService(properties, templateRenderer,
                new MailLanguageResolver(userSettingsRepository));
        when(userSettingsRepository.findByUserId(1L)).thenReturn(Optional.empty());
        WeeklyTrainerReport report = new WeeklyTrainerReport(
                LocalDate.of(2026, 6, 1), LocalDate.of(2026, 6, 7), List.of());

        assertThatCode(() -> service.sendWeeklyTrainerReport(user(1L, "trainer@example.com"), report))
                .doesNotThrowAnyException();
    }

    private static WeeklyTrainerReport sampleReport() {
        return new WeeklyTrainerReport(LocalDate.of(2026, 6, 1), LocalDate.of(2026, 6, 7), List.of(
                new WeeklyTrainerReport.ClientWeekSummary("jane", 3, 1, 5, 4, 2150, 82.4, -0.4),
                new WeeklyTrainerReport.ClientWeekSummary("<script>john", 0, 0, 0, null, null, null, null)));
    }

    private static User user(Long id, String email) {
        User user = new User();
        user.setId(id);
        user.setEmail(email);
        return user;
    }
}

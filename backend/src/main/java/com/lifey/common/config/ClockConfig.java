package com.lifey.common.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.time.Clock;

/**
 * The application's source of "now".
 *
 * <p>Injected rather than called statically ({@code Clock.systemUTC()}) so every
 * scheduled job that reasons about time — {@code WorkoutReminderJob},
 * {@code TrainerWeeklyReportJob}, {@code ChatUnreadReminderJob} — is testable
 * with a fixed instant.
 *
 * <p>Lives in {@code common} because three unrelated features depend on it. It
 * used to be declared in {@code PushConfig}, which made every one of them
 * silently depend on the push module through the Spring context rather than
 * through an import — a coupling invisible to any static check
 * (docs/chat/44-chat-service-extraction-plan.md §2.5).
 */
@Configuration
public class ClockConfig {

    @Bean
    Clock clock() {
        return Clock.systemUTC();
    }
}

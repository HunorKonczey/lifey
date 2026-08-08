package com.lifey.common.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.time.Clock;

/**
 * This service's source of "now".
 *
 * <p>Injected rather than called statically ({@code Clock.systemUTC()}) so the
 * two things that reason about time — {@code ChatUnreadReminderJob} and the
 * quiet-hours gate in {@code ChatNotificationServiceImpl} — are testable with a
 * fixed instant.
 *
 * <p>In the monolith this bean is declared in {@code common.config.ClockConfig}
 * too. It used to live in {@code PushConfig}, where it silently coupled the chat
 * to the push module through the Spring context rather than through an import —
 * the kind of dependency no static check would have caught on the way out
 * (docs/chat/44-chat-service-extraction-plan.md §2.5).
 */
@Configuration
public class ClockConfig {

    @Bean
    Clock clock() {
        return Clock.systemUTC();
    }
}

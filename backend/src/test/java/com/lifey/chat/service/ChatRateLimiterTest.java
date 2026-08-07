package com.lifey.chat.service;

import com.lifey.chat.ChatProperties;
import com.lifey.chat.exception.ChatRateLimitedException;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Duration;

class ChatRateLimiterTest {

    @Test
    void allowsUpToTheMinuteBudgetThenRejects() {
        ChatRateLimiter limiter = limiterWith(3, 100);

        for (int i = 0; i < 3; i++) {
            limiter.requireSendAllowance(1L);
        }

        assertThatThrownBy(() -> limiter.requireSendAllowance(1L))
                .isInstanceOf(ChatRateLimitedException.class);
    }

    @Test
    void countsTheDailyBudgetSeparatelyFromTheMinuteBudget() {
        ChatRateLimiter limiter = limiterWith(100, 2);

        limiter.requireSendAllowance(1L);
        limiter.requireSendAllowance(1L);

        assertThatThrownBy(() -> limiter.requireSendAllowance(1L))
                .isInstanceOf(ChatRateLimitedException.class);
    }

    @Test
    void budgetsAreTrackedPerUser() {
        ChatRateLimiter limiter = limiterWith(1, 100);

        limiter.requireSendAllowance(1L);

        assertThatCode(() -> limiter.requireSendAllowance(2L)).doesNotThrowAnyException();
    }

    private static ChatRateLimiter limiterWith(int perMinute, int perDay) {
        return new ChatRateLimiter(new ChatProperties(true, 2000, 30, 100, perMinute, perDay,
                Duration.ofMinutes(5), 200, Duration.ofMinutes(2),
                Duration.ofSeconds(60), Duration.ofMinutes(30), 1, false, Duration.ofHours(24),
                8L * 1024 * 1024, 1600, 400));
    }
}

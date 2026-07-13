package com.lifey.auth;

import com.lifey.auth.repository.PasswordResetTokenRepository;

import lombok.RequiredArgsConstructor;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;

/**
 * Daily sweep removing expired/used password reset tokens older than 24h.
 */
@Component
@RequiredArgsConstructor
class PasswordResetTokenCleanupJob {

    private static final Duration RETENTION = Duration.ofHours(24);

    private final PasswordResetTokenRepository tokenRepository;

    @Scheduled(cron = "${lifey.jobs.password-reset-cleanup.cron}")
    @Transactional
    void cleanUpStaleTokens() {
        tokenRepository.deleteStaleTokens(Instant.now().minus(RETENTION));
    }
}

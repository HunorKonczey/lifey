package com.lifey.auth;

import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;

/** Daily sweep removing expired/used password reset tokens older than 24h. */
@Component
class PasswordResetTokenCleanupJob {

    private static final Duration RETENTION = Duration.ofHours(24);

    private final PasswordResetTokenRepository tokenRepository;

    PasswordResetTokenCleanupJob(PasswordResetTokenRepository tokenRepository) {
        this.tokenRepository = tokenRepository;
    }

    @Scheduled(cron = "0 0 3 * * *")
    @Transactional
    void cleanUpStaleTokens() {
        tokenRepository.deleteStaleTokens(Instant.now().minus(RETENTION));
    }
}

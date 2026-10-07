package com.lifey.idempotency;

import com.lifey.idempotency.service.IdempotencyService;
import lombok.RequiredArgsConstructor;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** Daily sweep removing idempotency keys no client could still be retrying. */
@Component
@RequiredArgsConstructor
class IdempotencyKeyCleanupJob {

    private final IdempotencyService idempotencyService;

    @Scheduled(cron = "${lifey.jobs.idempotency-cleanup.cron}")
    void cleanUpExpiredKeys() {
        idempotencyService.deleteExpired();
    }
}

package com.lifey.trainer;

import lombok.RequiredArgsConstructor;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;

/**
 * Daily sweep flipping expired PENDING invites to EXPIRED (docs/personal_trainer/
 * 02-domain-es-migraciok.md, "Változás 2"). Purely cosmetic bookkeeping: every
 * read path already filters PENDING rows by {@code expiresAt > now}, so the
 * system is correct even if this job never runs — it just keeps the status
 * column honest for anyone querying the table directly.
 */
@Component
@RequiredArgsConstructor
class TrainerClientCleanupJob {

    private final TrainerClientRepository trainerClientRepository;

    @Scheduled(cron = "0 30 3 * * *")
    @Transactional
    void expireStaleInvites() {
        trainerClientRepository.expireStalePendingInvites(Instant.now());
    }
}

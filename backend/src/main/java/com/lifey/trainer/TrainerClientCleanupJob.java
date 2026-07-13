package com.lifey.trainer;

import lombok.RequiredArgsConstructor;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;

/**
 * Daily sweep flipping expired PENDING invites to EXPIRED (docs/personal_trainer/
 * 02-domain-es-migraciok.md, "Változás 2"). Read paths already filter PENDING rows
 * by {@code expiresAt > now}, but the "one live row per pair" unique index treats
 * PENDING as live regardless of expiresAt, so {@link com.lifey.trainer.service.TrainerInviteServiceImpl#invite}
 * also self-heals a single stale row inline on re-invite — this job just keeps the
 * status column honest in the general case (and for pairs nobody re-invites).
 */
@Component
@RequiredArgsConstructor
class TrainerClientCleanupJob {

    private final TrainerClientRepository trainerClientRepository;

    @Scheduled(cron = "${lifey.jobs.trainer-client-cleanup.cron}")
    @Transactional
    void expireStaleInvites() {
        trainerClientRepository.expireStalePendingInvites(Instant.now());
    }
}

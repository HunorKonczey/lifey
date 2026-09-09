package com.lifey.trainer;

import com.lifey.trainer.entity.TrainerClient;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface TrainerClientRepository extends JpaRepository<TrainerClient, Long> {

    boolean existsByTrainerIdAndClientIdAndStatus(Long trainerId, Long clientId, TrainerClientStatus status);

    /** Rate-limit check: the most recent invite between this pair, regardless of outcome. */
    Optional<TrainerClient> findFirstByTrainerIdAndClientIdOrderByCreatedAtDesc(Long trainerId, Long clientId);

    /** Global per-trainer cap on invites sent, counted over the same rolling window as the rate limit. */
    long countByTrainerIdAndCreatedAtAfter(Long trainerId, Instant since);

    /**
     * The one canonical active-client count (63 §8.1) — read by both the
     * entitlement resolver's trainer block and, from `64` Prompt 3 on,
     * {@code SeatLimitService}'s enforcement. A trainer count that disagrees
     * with the display is exactly the silent failure that risk checkpoint
     * warns about, so nothing else may re-implement this query.
     */
    long countByTrainerIdAndStatus(Long trainerId, TrainerClientStatus status);

    /** Non-expired pending invites — counted toward the seat limit on send (docs/landing_page/64-billing-backend-plan.md §4.3). */
    long countByTrainerIdAndStatusAndExpiresAtAfter(Long trainerId, TrainerClientStatus status, Instant now);

    List<TrainerClient> findByTrainerIdAndStatusAndExpiresAtAfterOrderByCreatedAtDesc(
            Long trainerId, TrainerClientStatus status, Instant now);

    Optional<TrainerClient> findByIdAndTrainerIdAndStatus(Long id, Long trainerId, TrainerClientStatus status);

    List<TrainerClient> findByTrainerIdAndStatusOrderByRespondedAtDesc(Long trainerId, TrainerClientStatus status);

    Optional<TrainerClient> findByTrainerIdAndClientIdAndStatus(Long trainerId, Long clientId, TrainerClientStatus status);

    List<TrainerClient> findByClientIdAndStatusAndExpiresAtAfterOrderByCreatedAtDesc(
            Long clientId, TrainerClientStatus status, Instant now);

    Optional<TrainerClient> findByIdAndClientIdAndStatus(Long id, Long clientId, TrainerClientStatus status);

    /** Looks up an invite by its email accept/decline token hash (see {@link TrainerClient#getEmailTokenHash()}). */
    Optional<TrainerClient> findByEmailTokenHashAndStatus(String emailTokenHash, TrainerClientStatus status);

    List<TrainerClient> findByClientIdAndStatusOrderByRespondedAtDesc(Long clientId, TrainerClientStatus status);

    @Modifying
    @Query("update TrainerClient tc set tc.status = com.lifey.trainer.TrainerClientStatus.EXPIRED "
            + "where tc.status = com.lifey.trainer.TrainerClientStatus.PENDING and tc.expiresAt < :now")
    void expireStalePendingInvites(@Param("now") Instant now);

    /** Every trainer with at least one active client — the weekly trainer report job's (docs/33) fan-out list. */
    @Query("select distinct tc.trainer.id from TrainerClient tc where tc.status = com.lifey.trainer.TrainerClientStatus.ACTIVE")
    List<Long> findTrainerIdsWithActiveClients();
}

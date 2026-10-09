package com.lifey.trainer;

import com.lifey.trainer.entity.TrainerInviteLink;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface TrainerInviteLinkRepository extends JpaRepository<TrainerInviteLink, Long> {

    Optional<TrainerInviteLink> findByTokenHash(String tokenHash);

    Optional<TrainerInviteLink> findByIdAndTrainerId(Long id, Long trainerId);

    /** The trainer's links that can still be used, newest first. */
    List<TrainerInviteLink> findByTrainerIdAndRedeemedAtIsNullAndRevokedAtIsNullAndExpiresAtAfterOrderByCreatedAtDesc(
            Long trainerId, Instant now);

    long countByTrainerIdAndRedeemedAtIsNullAndRevokedAtIsNullAndExpiresAtAfter(Long trainerId, Instant now);
}

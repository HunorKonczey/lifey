package com.lifey.trainer.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.trainer.TrainerClient;
import com.lifey.trainer.TrainerClientMapper;
import com.lifey.trainer.TrainerClientRepository;
import com.lifey.trainer.TrainerClientStatus;
import com.lifey.trainer.dto.PendingInviteResponse;
import com.lifey.trainer.dto.RespondToInviteRequest;
import com.lifey.trainer.dto.TrainerInviteRequest;
import com.lifey.trainer.dto.TrainerInviteResponse;
import com.lifey.trainer.exception.AlreadyClientException;
import com.lifey.trainer.exception.InviteNotFoundException;
import com.lifey.trainer.exception.InviteRateLimitedException;
import com.lifey.trainer.exception.SelfInviteException;
import com.lifey.trainer.exception.UserNotFoundForInviteException;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.List;

/**
 * Invite lifecycle (docs/personal_trainer/01-koncepcio-es-folyamatok.md,
 * "1. folyamat" and "Üzleti szabályok (meghívó)"). Relationship-level
 * operations (list active clients, revoke, leave) live in
 * {@link TrainerAccessService} instead — this service only owns the
 * PENDING/DECLINED lifecycle.
 */
@Service
@RequiredArgsConstructor
@Transactional
public class TrainerInviteServiceImpl implements TrainerInviteService {

    /**
     * Both the per-recipient cooldown and the PENDING invite's validity window —
     * deliberately the same duration (see the docs: "a rate-limit is épp ekkor jár le").
     */
    static final Duration INVITE_WINDOW = Duration.ofHours(24);

    /** Global per-trainer cap over the same rolling window, to blunt email enumeration. */
    static final int DAILY_INVITE_CAP = 20;

    private final TrainerClientRepository trainerClientRepository;
    private final UserRepository userRepository;
    private final CurrentUserProvider currentUserProvider;

    @Override
    public TrainerInviteResponse invite(TrainerInviteRequest request) {
        Long trainerId = currentUserProvider.getUserId();
        User client = userRepository.findByEmailIgnoreCase(request.email().trim())
                .orElseThrow(() -> new UserNotFoundForInviteException(
                        "No user with email: " + request.email()));

        if (client.getId().equals(trainerId)) {
            throw new SelfInviteException("Cannot invite yourself");
        }
        if (trainerClientRepository.existsByTrainerIdAndClientIdAndStatus(
                trainerId, client.getId(), TrainerClientStatus.ACTIVE)) {
            throw new AlreadyClientException("This user is already an active client");
        }

        Instant now = Instant.now();
        Instant windowStart = now.minus(INVITE_WINDOW);

        trainerClientRepository.findFirstByTrainerIdAndClientIdOrderByCreatedAtDesc(trainerId, client.getId())
                .filter(last -> last.getCreatedAt().isAfter(windowStart))
                .ifPresent(_ -> {
                    throw new InviteRateLimitedException(
                            "This user was already invited within the last 24 hours");
                });
        if (trainerClientRepository.countByTrainerIdAndCreatedAtAfter(trainerId, windowStart) >= DAILY_INVITE_CAP) {
            throw new InviteRateLimitedException("Daily invite limit reached");
        }

        TrainerClient invite = new TrainerClient();
        invite.setTrainer(userRepository.getReferenceById(trainerId));
        invite.setClient(client);
        invite.setStatus(TrainerClientStatus.PENDING);
        invite.setCreatedAt(now);
        invite.setExpiresAt(now.plus(INVITE_WINDOW));
        return TrainerClientMapper.toInviteResponse(trainerClientRepository.save(invite));
    }

    @Override
    @Transactional(readOnly = true)
    public List<TrainerInviteResponse> findPendingForTrainer() {
        return trainerClientRepository.findByTrainerIdAndStatusAndExpiresAtAfterOrderByCreatedAtDesc(
                        currentUserProvider.getUserId(), TrainerClientStatus.PENDING, Instant.now())
                .stream()
                .map(TrainerClientMapper::toInviteResponse)
                .toList();
    }

    @Override
    public void cancel(Long inviteId) {
        TrainerClient invite = trainerClientRepository.findByIdAndTrainerIdAndStatus(
                        inviteId, currentUserProvider.getUserId(), TrainerClientStatus.PENDING)
                .filter(tc -> tc.getExpiresAt().isAfter(Instant.now()))
                .orElseThrow(() -> new InviteNotFoundException("Invite not found: " + inviteId));

        invite.setStatus(TrainerClientStatus.REVOKED);
        invite.setRevokedAt(Instant.now());
        invite.setRevokedBy(currentUserProvider.getUserId());
    }

    @Override
    @Transactional(readOnly = true)
    public List<PendingInviteResponse> findPendingForClient() {
        return trainerClientRepository.findByClientIdAndStatusAndExpiresAtAfterOrderByCreatedAtDesc(
                        currentUserProvider.getUserId(), TrainerClientStatus.PENDING, Instant.now())
                .stream()
                .map(TrainerClientMapper::toPendingInviteResponse)
                .toList();
    }

    @Override
    public void respond(Long inviteId, RespondToInviteRequest request) {
        TrainerClient invite = trainerClientRepository.findByIdAndClientIdAndStatus(
                        inviteId, currentUserProvider.getUserId(), TrainerClientStatus.PENDING)
                .filter(tc -> tc.getExpiresAt().isAfter(Instant.now()))
                .orElseThrow(() -> new InviteNotFoundException("Invite not found: " + inviteId));

        invite.setStatus(request.accept() ? TrainerClientStatus.ACTIVE : TrainerClientStatus.DECLINED);
        invite.setRespondedAt(Instant.now());
    }
}

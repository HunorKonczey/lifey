package com.lifey.trainer.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.auth.TokenHasher;
import com.lifey.billing.service.SeatLimitService;
import com.lifey.trainer.TrainerClientRepository;
import com.lifey.trainer.TrainerClientStatus;
import com.lifey.trainer.TrainerInviteLinkRepository;
import com.lifey.trainer.dto.CreatedTrainerInviteLinkResponse;
import com.lifey.trainer.dto.InviteLinkPreviewResponse;
import com.lifey.trainer.dto.TrainerInviteLinkResponse;
import com.lifey.trainer.entity.TrainerClient;
import com.lifey.trainer.entity.TrainerInviteLink;
import com.lifey.trainer.exception.AlreadyClientException;
import com.lifey.trainer.exception.InviteNotFoundException;
import com.lifey.trainer.exception.InviteRateLimitedException;
import com.lifey.trainer.exception.SelfInviteException;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.List;

/**
 * Shareable join links (LIF-103). A link is the trainer's open invitation: it carries no account until somebody redeems
 * it, and redeeming it creates the same ACTIVE {@link TrainerClient} row an accepted email invite leaves behind — so the
 * seat limit, the invite history and the chat all see an ordinary client.
 */
@Service
@RequiredArgsConstructor
@Transactional
public class TrainerInviteLinkServiceImpl implements TrainerInviteLinkService {

    /** Long enough to be sent over a chat and opened the next day, short enough that a forgotten link dies. */
    static final Duration LINK_VALIDITY = Duration.ofDays(7);

    /** A trainer cannot pile up links: every live one is a standing offer of a seat. */
    static final int MAX_ACTIVE_LINKS = 5;

    private final TrainerInviteLinkRepository linkRepository;
    private final TrainerClientRepository trainerClientRepository;
    private final UserRepository userRepository;
    private final CurrentUserProvider currentUserProvider;
    private final SeatLimitService seatLimitService;

    @Override
    public CreatedTrainerInviteLinkResponse create() {
        Long trainerId = currentUserProvider.getUserId();
        // A link offers a seat like a sent invite does (64 §4.3), so a trainer at capacity cannot make one.
        seatLimitService.assertCanSendInvite(trainerId);

        Instant now = Instant.now();
        if (linkRepository.countByTrainerIdAndRedeemedAtIsNullAndRevokedAtIsNullAndExpiresAtAfter(trainerId, now)
                >= MAX_ACTIVE_LINKS) {
            throw new InviteRateLimitedException("Too many active invite links - revoke one first");
        }

        String token = TokenHasher.generateOpaqueToken();
        TrainerInviteLink link = new TrainerInviteLink();
        link.setTrainer(userRepository.getReferenceById(trainerId));
        link.setTokenHash(TokenHasher.hash(token));
        link.setCreatedAt(now);
        link.setExpiresAt(now.plus(LINK_VALIDITY));
        TrainerInviteLink saved = linkRepository.save(link);

        return new CreatedTrainerInviteLinkResponse(saved.getId(), token, saved.getCreatedAt(), saved.getExpiresAt());
    }

    @Override
    @Transactional(readOnly = true)
    public List<TrainerInviteLinkResponse> findActiveForTrainer() {
        return linkRepository
                .findByTrainerIdAndRedeemedAtIsNullAndRevokedAtIsNullAndExpiresAtAfterOrderByCreatedAtDesc(
                        currentUserProvider.getUserId(), Instant.now())
                .stream()
                .map(l -> new TrainerInviteLinkResponse(l.getId(), l.getCreatedAt(), l.getExpiresAt()))
                .toList();
    }

    @Override
    public void revoke(Long linkId) {
        TrainerInviteLink link = linkRepository.findByIdAndTrainerId(linkId, currentUserProvider.getUserId())
                .filter(l -> l.isLive(Instant.now()))
                .orElseThrow(() -> new InviteNotFoundException("Invite link not found: " + linkId));
        link.setRevokedAt(Instant.now());
    }

    @Override
    @Transactional(readOnly = true)
    public InviteLinkPreviewResponse preview(String token) {
        TrainerInviteLink link = requireLiveLink(token);
        return new InviteLinkPreviewResponse(displayName(link.getTrainer()));
    }

    @Override
    public void redeem(String token) {
        TrainerInviteLink link = requireLiveLink(token);
        Long trainerId = link.getTrainer().getId();
        Long userId = currentUserProvider.getUserId();

        if (trainerId.equals(userId)) {
            throw new SelfInviteException("Cannot join your own invite link");
        }
        if (trainerClientRepository.existsByTrainerIdAndClientIdAndStatus(trainerId, userId, TrainerClientStatus.ACTIVE)) {
            throw new AlreadyClientException("You are already this trainer's client");
        }
        // Re-checked right before the seat is taken, in this transaction, like the accept of an email invite.
        seatLimitService.assertCanAcquireClientForAccept(trainerId);

        Instant now = Instant.now();
        // The pair may already have an email invite waiting: the link answers it, so promote that row rather than
        // inserting a second live one for the same pair (the unique index allows only one).
        TrainerClient relationship = trainerClientRepository
                .findFirstByTrainerIdAndClientIdOrderByCreatedAtDesc(trainerId, userId)
                .filter(last -> last.getStatus() == TrainerClientStatus.PENDING)
                .orElseGet(TrainerClient::new);
        if (relationship.getId() == null) {
            relationship.setTrainer(link.getTrainer());
            relationship.setClient(userRepository.getReferenceById(userId));
            relationship.setCreatedAt(now);
            relationship.setExpiresAt(now);
        }
        relationship.setStatus(TrainerClientStatus.ACTIVE);
        relationship.setRespondedAt(now);
        trainerClientRepository.save(relationship);

        link.setRedeemedAt(now);
        link.setRedeemedBy(userId);
    }

    private TrainerInviteLink requireLiveLink(String token) {
        // One answer for every way a link can be dead (never existed, used, revoked, expired): nothing to probe.
        return linkRepository.findByTokenHash(TokenHasher.hash(token))
                .filter(l -> l.isLive(Instant.now()))
                .orElseThrow(() -> new InviteNotFoundException("Invite link not found or no longer valid"));
    }

    private static String displayName(User user) {
        String first = user.getFirstName() == null ? "" : user.getFirstName().trim();
        String last = user.getLastName() == null ? "" : user.getLastName().trim();
        String full = (first + " " + last).trim();
        return full.isEmpty() ? user.getEmail() : full;
    }
}

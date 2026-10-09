package com.lifey.trainer.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.auth.TokenHasher;
import com.lifey.billing.service.SeatLimitService;
import com.lifey.mail.service.MailService;
import com.lifey.push.service.PushMessage;
import com.lifey.push.service.PushService;
import com.lifey.settings.LanguagePreference;
import com.lifey.settings.UserSettings;
import com.lifey.settings.UserSettingsRepository;
import com.lifey.trainer.TrainerClientMapper;
import com.lifey.trainer.TrainerClientRepository;
import com.lifey.trainer.TrainerClientStatus;
import com.lifey.trainer.TrainerInviteProperties;
import com.lifey.trainer.dto.PendingInviteResponse;
import com.lifey.trainer.dto.RespondToInviteRequest;
import com.lifey.trainer.dto.TrainerInviteRequest;
import com.lifey.trainer.dto.TrainerInviteHistoryResponse;
import com.lifey.trainer.dto.TrainerInviteResponse;
import com.lifey.trainer.entity.TrainerClient;
import com.lifey.trainer.exception.AlreadyClientException;
import com.lifey.trainer.exception.InviteNotFoundException;
import com.lifey.trainer.exception.InviteRateLimitedException;
import com.lifey.trainer.exception.SelfInviteException;
import com.lifey.trainer.exception.UserNotFoundForInviteException;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;

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

    /**
     * Least time between two reminders of one invite, counted from the invite or the last reminder (LIF-103). An invite
     * lives 24 hours, so this allows a handful, but never a nag.
     */
    static final Duration REMINDER_COOLDOWN = Duration.ofHours(4);

    private final TrainerClientRepository trainerClientRepository;
    private final UserRepository userRepository;
    private final CurrentUserProvider currentUserProvider;
    private final MailService mailService;
    private final TrainerInviteProperties trainerInviteProperties;
    private final SeatLimitService seatLimitService;
    private final PushService pushService;
    private final UserSettingsRepository userSettingsRepository;

    @Override
    public TrainerInviteResponse invite(TrainerInviteRequest request) {
        Long trainerId = currentUserProvider.getUserId();
        // Pending invites count toward the limit too (64 §4.3) — checked before
        // the email lookup so a trainer at capacity gets one consistent error
        // regardless of who they tried to invite.
        seatLimitService.assertCanSendInvite(trainerId);

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

        var lastInvite = trainerClientRepository
                .findFirstByTrainerIdAndClientIdOrderByCreatedAtDesc(trainerId, client.getId());
        lastInvite
                .filter(last -> last.getCreatedAt().isAfter(windowStart))
                .ifPresent(_ -> {
                    throw new InviteRateLimitedException(
                            "This user was already invited within the last 24 hours");
                });
        if (trainerClientRepository.countByTrainerIdAndCreatedAtAfter(trainerId, windowStart) >= DAILY_INVITE_CAP) {
            throw new InviteRateLimitedException("Daily invite limit reached");
        }

        // The nightly cleanup job only flips stale PENDING invites to EXPIRED once a
        // day, but the "one live row per pair" unique index treats PENDING as live
        // regardless of expiresAt — so without this, a re-invite fails with a
        // constraint violation until the job catches up. Self-heal here instead.
        // The flush is required: the new invite's INSERT below runs immediately
        // (identity-generated id), before this UPDATE would otherwise be flushed
        // at commit time, so without it the old row is still PENDING when the
        // unique constraint is checked.
        lastInvite
                .filter(last -> last.getStatus() == TrainerClientStatus.PENDING)
                .filter(last -> !last.getExpiresAt().isAfter(now))
                .ifPresent(last -> {
                    last.setStatus(TrainerClientStatus.EXPIRED);
                    trainerClientRepository.saveAndFlush(last);
                });

        User trainer = userRepository.getReferenceById(trainerId);

        TrainerClient invite = new TrainerClient();
        invite.setTrainer(trainer);
        invite.setClient(client);
        invite.setStatus(TrainerClientStatus.PENDING);
        invite.setCreatedAt(now);
        invite.setExpiresAt(now.plus(INVITE_WINDOW));

        // The email channel is optional (lifey.trainer-invite.email-enabled) and
        // additive to the mobile polling flow: the token only exists to let the
        // client accept/decline from the emailed link without being logged in.
        String emailToken = null;
        if (trainerInviteProperties.emailEnabled()) {
            emailToken = TokenHasher.generateOpaqueToken();
            invite.setEmailTokenHash(TokenHasher.hash(emailToken));
        }

        TrainerClient saved = trainerClientRepository.save(invite);

        if (emailToken != null) {
            String baseUrl = trainerInviteProperties.publicBaseUrl();
            String acceptUrl = baseUrl + "/api/v1/trainer-invites/email/respond?token=" + emailToken + "&accept=true";
            String declineUrl = baseUrl + "/api/v1/trainer-invites/email/respond?token=" + emailToken + "&accept=false";
            mailService.sendTrainerInviteEmail(client, trainer, acceptUrl, declineUrl);
        }

        return TrainerClientMapper.toInviteResponse(saved);
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
    @Transactional(readOnly = true)
    public Page<TrainerInviteHistoryResponse> findHistoryForTrainer(Pageable pageable) {
        Instant now = Instant.now();
        // The sort is fixed by the repository method (newest first); a caller-supplied sort is dropped on purpose.
        Pageable fixed = PageRequest.of(pageable.getPageNumber(), pageable.getPageSize());
        return trainerClientRepository.findByTrainerIdOrderByCreatedAtDescIdDesc(currentUserProvider.getUserId(), fixed)
                .map(tc -> TrainerClientMapper.toInviteHistoryResponse(tc, now));
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
    public TrainerInviteResponse remind(Long inviteId) {
        Long trainerId = currentUserProvider.getUserId();
        TrainerClient invite = trainerClientRepository.findByIdAndTrainerIdAndStatus(
                        inviteId, trainerId, TrainerClientStatus.PENDING)
                .filter(tc -> tc.getExpiresAt().isAfter(Instant.now()))
                .orElseThrow(() -> new InviteNotFoundException("Invite not found: " + inviteId));

        Instant now = Instant.now();
        Instant since = invite.getLastRemindedAt() != null ? invite.getLastRemindedAt() : invite.getCreatedAt();
        if (since.isAfter(now.minus(REMINDER_COOLDOWN))) {
            throw new InviteRateLimitedException("This invite was reminded or sent too recently");
        }
        invite.setLastRemindedAt(now);

        User trainer = invite.getTrainer();
        User client = invite.getClient();
        sendReminderPush(trainer, client);

        if (trainerInviteProperties.emailEnabled()) {
            // The earlier token cannot be read back from its hash, so the reminder mail carries a new one and the old
            // links stop working - one live set of links per invite.
            String emailToken = TokenHasher.generateOpaqueToken();
            invite.setEmailTokenHash(TokenHasher.hash(emailToken));
            String baseUrl = trainerInviteProperties.publicBaseUrl();
            String acceptUrl = baseUrl + "/api/v1/trainer-invites/email/respond?token=" + emailToken + "&accept=true";
            String declineUrl = baseUrl + "/api/v1/trainer-invites/email/respond?token=" + emailToken + "&accept=false";
            mailService.sendTrainerInviteEmail(client, trainer, acceptUrl, declineUrl);
        }

        return TrainerClientMapper.toInviteResponse(invite);
    }

    private void sendReminderPush(User trainer, User client) {
        boolean hungarian = userSettingsRepository.findByUserId(client.getId())
                .map(UserSettings::getLanguage)
                .map(l -> l == LanguagePreference.HUNGARIAN)
                .orElse(false);
        String who = displayName(trainer);
        String title = hungarian ? "Egy edző válaszodra vár" : "A trainer is waiting for your answer";
        String body = hungarian
                ? who + " meghívott kliensnek - fogadd el vagy utasítsd el a meghívót"
                : who + " invited you to be their client - accept or decline the invite";
        pushService.sendToUser(client.getId(), new PushMessage(title, body, Map.of("type", "trainer_invite")));
    }

    private static String displayName(User user) {
        String first = user.getFirstName() == null ? "" : user.getFirstName().trim();
        String last = user.getLastName() == null ? "" : user.getLastName().trim();
        String full = (first + " " + last).trim();
        return full.isEmpty() ? user.getEmail() : full;
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

        applyResponse(invite, request.accept());
    }

    @Override
    public void respondViaEmailToken(String token, boolean accept) {
        TrainerClient invite = trainerClientRepository
                .findByEmailTokenHashAndStatus(TokenHasher.hash(token), TrainerClientStatus.PENDING)
                .filter(tc -> tc.getExpiresAt().isAfter(Instant.now()))
                .orElseThrow(() -> new InviteNotFoundException("Invite not found or already responded to"));

        applyResponse(invite, accept);
    }

    /**
     * Shared by both accept paths ({@link #respond} and {@link
     * #respondViaEmailToken}): the seat re-check (64 §4.3, 63 §7.6) happens
     * inside this same transaction, right before the mutation, so the
     * {@code SELECT … FOR UPDATE} it takes is actually held across both — a
     * concurrent accept racing for the last seat gets a 409, not a 13th seat.
     */
    private void applyResponse(TrainerClient invite, boolean accept) {
        if (accept) {
            seatLimitService.assertCanAcquireClientForAccept(invite.getTrainer().getId());
        }
        invite.setStatus(accept ? TrainerClientStatus.ACTIVE : TrainerClientStatus.DECLINED);
        invite.setRespondedAt(Instant.now());
    }
}

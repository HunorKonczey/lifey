package com.lifey.billing.service;

import com.lifey.billing.BillingProperties;
import com.lifey.billing.dto.EntitlementResponse;
import com.lifey.billing.dto.EntitlementSource;
import com.lifey.billing.dto.EntitlementTier;
import com.lifey.billing.dto.TrainerEntitlement;
import com.lifey.billing.entity.Subscription;
import com.lifey.billing.entity.SubscriptionProvider;
import com.lifey.billing.entity.SubscriptionStatus;
import com.lifey.billing.repository.SubscriptionRepository;
import com.lifey.trainer.TrainerClientRepository;
import com.lifey.trainer.TrainerClientStatus;
import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.EnumSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;

/**
 * The resolver from docs/landing_page/63-monetization-strategy-plan.md §3.
 * Pure and cheap: at most two queries (the user's own subscriptions, and the
 * sponsoring trainers' subscriptions via a single join), first-match-wins
 * over the same five branches every time (docs/landing_page/64-billing-backend-plan.md D-B3).
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
@Slf4j
public class EntitlementServiceImpl implements EntitlementService {

    /** Kept access through Stripe's ~2-week dunning window (63 §7.5) — sponsored clients follow suit. */
    private static final Set<SubscriptionStatus> ENTITLING_STATUSES =
            EnumSet.of(SubscriptionStatus.ACTIVE, SubscriptionStatus.TRIALING, SubscriptionStatus.PAST_DUE);

    /** Excludes TRIALING deliberately — a trainer's own trial is resolved separately, gated on {@code trialEndsAt}. */
    private static final Set<SubscriptionStatus> OWN_PAID_STATUSES =
            EnumSet.of(SubscriptionStatus.ACTIVE, SubscriptionStatus.PAST_DUE);

    private final UserRepository userRepository;
    private final SubscriptionRepository subscriptionRepository;
    private final TrainerClientRepository trainerClientRepository;
    private final BillingProperties billingProperties;
    private final AiUsageCounterService aiUsageCounterService;
    private final Clock clock;

    @Override
    public EntitlementResponse resolve(Long userId) {
        try {
            return doResolve(userId);
        } catch (Exception ex) {
            log.error("Entitlement resolution failed for user {}, failing open", userId, ex);
            return openResponse(clock.instant(), null, true);
        }
    }

    private EntitlementResponse doResolve(Long userId) {
        Instant now = clock.instant();

        User user = userRepository.findById(userId).orElse(null);
        if (user == null) {
            return freeResponse(now, null, userId);
        }

        List<Subscription> ownSubscriptions = subscriptionRepository.findByUserId(userId);
        TrainerEntitlement trainerBlock = user.getRoles().contains(Role.ROLE_TRAINER)
                ? buildTrainerBlock(userId, ownSubscriptions)
                : null;

        if (!billingProperties.enabled()) {
            return openResponse(now, trainerBlock, false);
        }

        // 1. ROLE_SUPER_ADMIN or an internal comp flag (a COMP-provider row).
        if (user.getRoles().contains(Role.ROLE_SUPER_ADMIN)) {
            return proResponse(EntitlementSource.COMP, null, now, trainerBlock);
        }
        Optional<Subscription> comp = ownSubscriptions.stream()
                .filter(s -> s.getProvider() == SubscriptionProvider.COMP && ENTITLING_STATUSES.contains(s.getStatus()))
                .findFirst();
        if (comp.isPresent()) {
            return proResponse(EntitlementSource.COMP, comp.get().getCurrentPeriodEnd(), now, trainerBlock);
        }

        // 2. Own active paid subscription (APP_STORE / PLAY_STORE / STRIPE).
        Optional<Subscription> ownPaid = ownSubscriptions.stream()
                .filter(s -> s.getProvider() != SubscriptionProvider.COMP)
                .filter(s -> OWN_PAID_STATUSES.contains(s.getStatus()))
                .findFirst();
        if (ownPaid.isPresent()) {
            Subscription s = ownPaid.get();
            return proResponse(toSource(s.getProvider()), s.getCurrentPeriodEnd(), now, trainerBlock);
        }

        // 3. Active TrainerClient whose trainer holds entitling billing.
        Optional<Subscription> sponsor = subscriptionRepository.findSponsoringSubscriptionsForActiveClient(userId)
                .stream()
                .filter(s -> ENTITLING_STATUSES.contains(s.getStatus()))
                .findFirst();
        if (sponsor.isPresent()) {
            return proResponse(EntitlementSource.TRAINER_SPONSORED, sponsor.get().getCurrentPeriodEnd(), now, trainerBlock);
        }

        // 4. Own trainer trial still in date.
        Optional<Subscription> ownTrial = ownSubscriptions.stream()
                .filter(s -> s.getStatus() == SubscriptionStatus.TRIALING)
                .filter(s -> s.getTrialEndsAt() != null && s.getTrialEndsAt().isAfter(now))
                .findFirst();
        // 5. Otherwise, FREE.
        return ownTrial.map(subscription ->
                        proResponse(EntitlementSource.TRAINER_TRIAL, subscription.getTrialEndsAt(), now, trainerBlock))
                .orElseGet(() -> freeResponse(now, trainerBlock, userId));
    }

    private TrainerEntitlement buildTrainerBlock(Long userId, List<Subscription> ownSubscriptions) {
        Subscription trainerSub = ownSubscriptions.stream()
                .filter(s -> s.getProvider() == SubscriptionProvider.STRIPE)
                .findFirst()
                .orElse(null);
        int activeClients = (int) trainerClientRepository.countByTrainerIdAndStatus(userId, TrainerClientStatus.ACTIVE);
        return new TrainerEntitlement(
                trainerSub != null ? trainerSub.getPlan() : null,
                trainerSub != null ? trainerSub.getStatus() : null,
                trainerSub != null && trainerSub.getPlan() != null ? trainerSub.getPlan().getMaxClients() : null,
                activeClients,
                trainerSub != null ? trainerSub.getTrialEndsAt() : null);
    }

    private static EntitlementSource toSource(SubscriptionProvider provider) {
        return switch (provider) {
            case STRIPE -> EntitlementSource.STRIPE;
            case APP_STORE -> EntitlementSource.APP_STORE;
            case PLAY_STORE -> EntitlementSource.PLAY_STORE;
            case COMP -> EntitlementSource.COMP;
        };
    }

    private EntitlementResponse proResponse(EntitlementSource source, Instant expiresAt, Instant now, TrainerEntitlement trainer) {
        return new EntitlementResponse(EntitlementTier.PRO, source, false, null, null,
                trainer, expiresAt, now, graceUntil(now), false);
    }

    /** The `lifey.billing.enabled=false` rollback switch (64 §1 point 6, §14 risk 1) — open for everyone, nothing degraded. */
    private EntitlementResponse openResponse(Instant now, TrainerEntitlement trainer, boolean degraded) {
        return new EntitlementResponse(EntitlementTier.PRO, EntitlementSource.COMP, false, null, null,
                trainer, null, now, graceUntil(now), degraded);
    }

    /**
     * `64` Prompt 12 (§3.4): {@code aiCreditsRemaining} reflects the real
     * {@code ai_usage_counter} row for the current calendar month, not the
     * flat monthly allowance — clamped at 0 rather than going negative if
     * usage somehow exceeds the limit (e.g. the limit was lowered mid-month).
     */
    private EntitlementResponse freeResponse(Instant now, TrainerEntitlement trainer, Long userId) {
        int remaining = Math.max(0, billingProperties.freeAiCreditsPerMonth() - aiUsageCounterService.usedThisMonth(userId));
        return new EntitlementResponse(EntitlementTier.FREE, EntitlementSource.NONE, true,
                billingProperties.freeHistoryDays(), remaining,
                trainer, null, now, graceUntil(now), false);
    }

    private Instant graceUntil(Instant now) {
        return now.plus(billingProperties.offlineGraceDays(), ChronoUnit.DAYS);
    }
}

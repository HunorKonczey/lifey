package com.lifey.billing.service;

import com.lifey.billing.entity.ProcessedBillingEvent;
import com.lifey.billing.entity.Subscription;
import com.lifey.billing.entity.SubscriptionProvider;
import com.lifey.billing.entity.SubscriptionStatus;
import com.lifey.billing.entity.TrainerPlan;
import com.lifey.billing.repository.ProcessedBillingEventRepository;
import com.lifey.billing.repository.SubscriptionRepository;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;

/**
 * The only class allowed to mutate {@code subscription}
 * (docs/landing_page/64-billing-backend-plan.md D-B2). Webhooks, the store
 * purchase endpoint, the reconciliation job and the admin comp tool all go
 * through it — idempotency, "can we even resolve this event to a row" checks,
 * and the audit log (the log statements below) live here so a subscription
 * row changed from four places stays something one class can explain.
 *
 * <p>Every method that can't find the row it needs (a race between
 * {@code checkout.session.completed} and {@code customer.subscription.*}, an
 * event for a deleted user, §11.1/§11.7) logs a WARN and returns rather than
 * throwing — a webhook handler 4xx-ing Stripe just buys a retry storm, and
 * the reconciliation job (`64` Prompt 11) is the real backstop for anything
 * that stays unresolved.
 */
@Service
@RequiredArgsConstructor
@Transactional
@Slf4j
public class SubscriptionWriter {

    private final SubscriptionRepository subscriptionRepository;
    private final ProcessedBillingEventRepository processedBillingEventRepository;
    private final UserRepository userRepository;

    @Transactional(readOnly = true)
    public boolean isAlreadyProcessed(SubscriptionProvider provider, String eventId) {
        return processedBillingEventRepository.existsByProviderAndEventId(provider, eventId);
    }

    /**
     * Called after an event's business logic has been applied. Guards against
     * the sequential-replay case the *Verify* line in §9 Prompt 5 asks for; a
     * true concurrent double-delivery is not specifically hardened against
     * here (both deliveries would apply the same idempotent-in-effect
     * mutation) — the reconciliation job is the backstop for that rarer race.
     */
    public void markProcessed(SubscriptionProvider provider, String eventId, String eventType) {
        ProcessedBillingEvent event = new ProcessedBillingEvent();
        event.setProvider(provider);
        event.setEventId(eventId);
        event.setEventType(eventType);
        processedBillingEventRepository.save(event);
    }

    /**
     * {@code checkout.session.completed}: the only event that ties a user id
     * to a provider customer/subscription id (63 §3, D-B1). Finds-or-creates
     * the {@code (userId, provider)} row; a new row starts {@code ACTIVE} —
     * corrected, in virtually every real case, by the coincident {@code
     * customer.subscription.created} event this same webhook delivery batch
     * carries.
     */
    public void linkCheckoutSession(Long userId, SubscriptionProvider provider, String customerId, String providerSubscriptionId) {
        User user = userRepository.findById(userId).orElse(null);
        if (user == null) {
            // 64 §11.1: checkout completed on a since-deleted or not-yet-committed account.
            log.warn("Stripe checkout.session.completed for unknown user {}, skipping link", userId);
            return;
        }
        Subscription subscription = subscriptionRepository.findByUserIdAndProvider(userId, provider)
                .orElseGet(() -> {
                    Subscription created = new Subscription();
                    created.setUser(user);
                    created.setProvider(provider);
                    created.setStatus(SubscriptionStatus.ACTIVE);
                    return created;
                });
        subscription.setProviderCustomerId(customerId);
        subscription.setProviderSubscriptionId(providerSubscriptionId);
        subscriptionRepository.save(subscription);
        log.info("Linked user {} to {} customer {} subscription {}", userId, provider, customerId, providerSubscriptionId);
    }

    /**
     * {@code customer.subscription.created} / {@code .updated}: the full
     * state sync, found by {@code providerSubscriptionId} since these events
     * carry no user id at all.
     */
    public void syncSubscriptionState(SubscriptionProvider provider, String providerSubscriptionId,
                                       SubscriptionStatus status, TrainerPlan plan,
                                       Instant currentPeriodEnd, Instant trialEndsAt, boolean cancelAtPeriodEnd) {
        Subscription subscription = subscriptionRepository.findByProviderAndProviderSubscriptionId(provider, providerSubscriptionId)
                .orElse(null);
        if (subscription == null) {
            log.warn("No local subscription for {} {} yet (checkout.session.completed hasn't landed?), skipping sync",
                    provider, providerSubscriptionId);
            return;
        }
        SubscriptionStatus previousStatus = subscription.getStatus();
        subscription.setStatus(status);
        subscription.setPlan(plan);
        subscription.setCurrentPeriodEnd(currentPeriodEnd);
        subscription.setTrialEndsAt(trialEndsAt);
        subscription.setCancelAtPeriodEnd(cancelAtPeriodEnd);
        subscriptionRepository.save(subscription);
        log.info("Subscription {} {} status {} -> {}", provider, providerSubscriptionId, previousStatus, status);
    }

    /** {@code customer.subscription.deleted}, {@code invoice.paid}, {@code invoice.payment_failed}: a status-only change. */
    public void markStatus(SubscriptionProvider provider, String providerSubscriptionId, SubscriptionStatus status) {
        subscriptionRepository.findByProviderAndProviderSubscriptionId(provider, providerSubscriptionId)
                .ifPresentOrElse(subscription -> {
                    SubscriptionStatus previousStatus = subscription.getStatus();
                    subscription.setStatus(status);
                    subscriptionRepository.save(subscription);
                    log.info("Subscription {} {} status {} -> {}", provider, providerSubscriptionId, previousStatus, status);
                }, () -> log.warn("No local subscription for {} {}, skipping status={}", provider, providerSubscriptionId, status));
    }

    /**
     * {@code charge.refunded}: the charge carries a customer id but no
     * subscription id in this API version, so the lookup is by customer
     * rather than {@link #markStatus}'s usual subscription id (64 §7 edge
     * case 8 — nothing is deleted, only revoked on the next resolve).
     */
    public void markRefundedByCustomerId(SubscriptionProvider provider, String customerId) {
        subscriptionRepository.findByProviderAndProviderCustomerId(provider, customerId)
                .ifPresentOrElse(subscription -> {
                    subscription.setStatus(SubscriptionStatus.REFUNDED);
                    subscriptionRepository.save(subscription);
                    log.info("Subscription {} customer {} refunded", provider, customerId);
                }, () -> log.warn("No local subscription for {} customer {}, skipping refund", provider, customerId));
    }

    /**
     * A verified store purchase (64 §6.1). The caller has already resolved
     * the identity question (D-B6, 63 §7.7) — this only ever touches {@code
     * userId}'s own {@code (userId, provider)} row, finding-or-creating it,
     * so a second user's purchase of the same {@code providerSubscriptionId}
     * must be rejected by the caller before reaching here, not by this method.
     */
    public void linkStorePurchase(Long userId, SubscriptionProvider provider, String providerSubscriptionId,
                                   SubscriptionStatus status, Instant currentPeriodEnd) {
        User user = userRepository.findById(userId).orElse(null);
        if (user == null) {
            log.warn("Store purchase verified for unknown user {}, skipping link", userId);
            return;
        }
        Subscription subscription = subscriptionRepository.findByUserIdAndProvider(userId, provider)
                .orElseGet(() -> {
                    Subscription created = new Subscription();
                    created.setUser(user);
                    created.setProvider(provider);
                    return created;
                });
        subscription.setProviderSubscriptionId(providerSubscriptionId);
        subscription.setStatus(status);
        subscription.setCurrentPeriodEnd(currentPeriodEnd);
        subscriptionRepository.save(subscription);
        log.info("Linked user {} to {} subscription {}, status {}", userId, provider, providerSubscriptionId, status);
    }

    /**
     * {@code ROLE_TRAINER} granted (64 §4.1): starts the trial, unless the
     * trainer already has a Stripe-provider row. That guard matters on
     * re-grant after a revoke — history is kept (the row is never deleted),
     * so a previously-paying trainer must never be reset back to a fresh
     * trial just because their role was revoked and granted again.
     */
    public void startTrainerTrial(Long userId, TrainerPlan plan, Instant trialEndsAt) {
        User user = userRepository.findById(userId).orElse(null);
        if (user == null) {
            log.warn("ROLE_TRAINER granted to unknown user {}, skipping trial creation", userId);
            return;
        }
        if (subscriptionRepository.findByUserIdAndProvider(userId, SubscriptionProvider.STRIPE).isPresent()) {
            log.info("User {} already has a Stripe subscription row, skipping trial creation", userId);
            return;
        }
        Subscription trial = new Subscription();
        trial.setUser(user);
        trial.setProvider(SubscriptionProvider.STRIPE);
        trial.setStatus(SubscriptionStatus.TRIALING);
        trial.setPlan(plan);
        trial.setTrialEndsAt(trialEndsAt);
        subscriptionRepository.save(trial);
        log.info("Started {} trial for user {}, ends {}", plan, userId, trialEndsAt);
    }

    /**
     * The reconciliation job's trial-expiry sweep (64 §7 step 3). Found by
     * our own id rather than {@code providerSubscriptionId} — a trial that
     * never converted to a paid Stripe subscription may not have one yet.
     * A no-op if the row already moved on (e.g. upgraded) since the job
     * read it.
     */
    public void expireTrial(Long subscriptionId) {
        subscriptionRepository.findById(subscriptionId)
                .filter(subscription -> subscription.getStatus() == SubscriptionStatus.TRIALING)
                .ifPresent(subscription -> {
                    subscription.setStatus(SubscriptionStatus.EXPIRED);
                    subscriptionRepository.save(subscription);
                    log.info("Subscription {} trial expired", subscriptionId);
                });
    }
}

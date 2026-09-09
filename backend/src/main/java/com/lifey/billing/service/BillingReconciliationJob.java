package com.lifey.billing.service;

import com.apple.itunes.storekit.client.AppStoreServerAPIClient;
import com.apple.itunes.storekit.model.LastTransactionsItem;
import com.apple.itunes.storekit.model.Status;
import com.apple.itunes.storekit.model.StatusResponse;
import com.google.api.services.androidpublisher.model.SubscriptionPurchaseV2;
import com.lifey.billing.AppleProperties;
import com.lifey.billing.BillingProperties;
import com.lifey.billing.GoogleProperties;
import com.lifey.billing.StripeProperties;
import com.lifey.billing.entity.Subscription;
import com.lifey.billing.entity.SubscriptionProvider;
import com.lifey.billing.entity.SubscriptionStatus;
import com.lifey.billing.repository.SubscriptionRepository;
import com.stripe.net.RequestOptions;
import io.micrometer.core.instrument.MeterRegistry;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.Clock;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

/**
 * The daily safety net (docs/landing_page/64-billing-backend-plan.md §7),
 * 03:30 Europe/Budapest — same scheduling style as {@code TrainerWeeklyReportJob},
 * with an explicit {@code zone} since a *daily* sweep is more exposed to DST
 * drift than a once-a-week one already positioned hours inside every
 * relevant day.
 *
 * <p>`64` Prompt 7 (§9) built only the trial-expiry step (§7 point 3); this
 * class (Prompt 11) adds the provider re-fetch, diff-and-correct, and
 * per-provider metrics steps (§7 points 1, 2, 4).
 *
 * <p>Deliberately NOT {@code @Transactional} at the {@link #run()} level:
 * {@link #reconcileProviderTruth()} makes up to {@code reconciliationBatchSize}
 * outbound HTTP calls to Stripe/Apple/Google, and holding a database
 * connection/transaction open across that many blocking round trips risks
 * connection-pool exhaustion. Every actual write goes through
 * {@link SubscriptionWriter}, which is {@code @Transactional} on its own —
 * each row's correction commits independently, which is fine for a nightly
 * best-effort sweep.
 */
@Component
@RequiredArgsConstructor
@Slf4j
class BillingReconciliationJob {

    /** {@code CANCELED}/{@code EXPIRED}/{@code REFUNDED} rows have nothing left to reconcile against the provider. */
    private static final List<SubscriptionStatus> NON_TERMINAL_STATUSES =
            List.of(SubscriptionStatus.TRIALING, SubscriptionStatus.ACTIVE, SubscriptionStatus.PAST_DUE);

    private static final List<String> TERMINAL_STRIPE_STATUSES = List.of("canceled", "unpaid", "incomplete_expired");

    /** 64 §6.1: which Play subscription states still let the entitlement resolver see this as active/near-active. */
    private static final Set<String> PLAY_ACTIVE_STATES = Set.of("SUBSCRIPTION_STATE_ACTIVE", "SUBSCRIPTION_STATE_IN_GRACE_PERIOD");
    private static final Set<String> PLAY_PAST_DUE_STATES = Set.of("SUBSCRIPTION_STATE_ON_HOLD", "SUBSCRIPTION_STATE_PAUSED");

    private final SubscriptionRepository subscriptionRepository;
    private final SubscriptionWriter subscriptionWriter;
    private final BillingProperties billingProperties;
    private final StripeProperties stripeProperties;
    private final AppleProperties appleProperties;
    private final GoogleProperties googleProperties;
    private final PlayPurchaseClient playPurchaseClient;
    private final MeterRegistry meterRegistry;
    private final Clock clock;

    @Scheduled(cron = "${lifey.jobs.billing-reconciliation.cron}", zone = "Europe/Budapest")
    void run() {
        reconcileProviderTruth();
        expireStaleTrials();
    }

    // --- §7 steps 1, 2, 4: re-fetch, diff-and-correct, per-provider metrics ----------

    private void reconcileProviderTruth() {
        List<Subscription> candidates = subscriptionRepository.findByStatusInAndProviderSubscriptionIdIsNotNull(
                NON_TERMINAL_STATUSES, PageRequest.of(0, billingProperties.reconciliationBatchSize(), Sort.by("id")));

        // [checked, corrected] per provider (§7 point 4) — reported once at the end of
        // the run rather than per-row, so a provider with zero candidates this run
        // still isn't silently absent from what's actually a "nothing to check" state.
        Map<SubscriptionProvider, int[]> tally = new EnumMap<>(SubscriptionProvider.class);
        for (Subscription subscription : candidates) {
            SubscriptionProvider provider = subscription.getProvider();
            if (provider == SubscriptionProvider.COMP) {
                // An admin comp grant has no vendor to check against.
                continue;
            }
            int[] counts = tally.computeIfAbsent(provider, ignored -> new int[2]);
            counts[0]++;
            reconcileOne(subscription, provider, counts);
        }
        tally.forEach((provider, counts) -> {
            meterRegistry.counter("billing.reconciliation.rows_checked", "provider", provider.name()).increment(counts[0]);
            meterRegistry.counter("billing.reconciliation.rows_corrected", "provider", provider.name()).increment(counts[1]);
        });
    }

    private void reconcileOne(Subscription subscription, SubscriptionProvider provider, int[] counts) {
        SubscriptionStatus providerStatus = fetchProviderStatus(subscription);
        if (providerStatus == null || providerStatus == subscription.getStatus()) {
            return;
        }
        // Every line here is a webhook delivery that never arrived (§7 point 2) — a
        // corrected count that stays non-zero night after night is the signal that
        // this provider's webhook is broken, not just occasionally late.
        log.warn("Billing reconciliation: {} {} local status {} but the provider says {}, correcting",
                provider, subscription.getProviderSubscriptionId(), subscription.getStatus(), providerStatus);
        subscriptionWriter.markStatus(provider, subscription.getProviderSubscriptionId(), providerStatus);
        counts[1]++;
    }

    /** @return the provider's current status, or {@code null} if it could not be determined this run. */
    private SubscriptionStatus fetchProviderStatus(Subscription subscription) {
        try {
            return switch (subscription.getProvider()) {
                case STRIPE -> fetchStripeStatus(subscription.getProviderSubscriptionId());
                case APP_STORE -> fetchAppStoreStatus(subscription.getProviderSubscriptionId());
                case PLAY_STORE -> fetchPlayStatus(subscription.getProviderSubscriptionId());
                case COMP -> null;
            };
        } catch (Exception e) {
            // A rate limit, an outage, an unconfigured credential — any of these must
            // leave the local row untouched, not corrupt it. The row is simply
            // re-checked on tomorrow's run.
            log.warn("Billing reconciliation: could not re-fetch {} {} from the provider, skipping this run",
                    subscription.getProvider(), subscription.getProviderSubscriptionId(), e);
            return null;
        }
    }

    private SubscriptionStatus fetchStripeStatus(String subscriptionId) throws com.stripe.exception.StripeException {
        RequestOptions options = RequestOptions.builder().setApiKey(stripeProperties.secretKey()).build();
        com.stripe.model.Subscription stripeSubscription = com.stripe.model.Subscription.retrieve(subscriptionId, options);
        return mapStripeStatus(stripeSubscription.getStatus());
    }

    /**
     * Apple's coarse, subscription-group-level status — deliberately a different
     * signal than {@code StoreBillingServiceImpl}'s per-transaction {@code
     * revocationDate}/{@code expiresDate} check at initial verification (`64`
     * Prompt 8): this is the "ask the provider for the whole truth" call §7
     * actually asks for, not a re-verification of one already-trusted receipt.
     */
    private SubscriptionStatus fetchAppStoreStatus(String originalTransactionId) throws Exception {
        AppStoreServerAPIClient client = new AppStoreServerAPIClient(appleProperties.privateKey(),
                appleProperties.keyId(), appleProperties.issuerId(), appleProperties.bundleId(), appleProperties.environment());
        StatusResponse response = client.getAllSubscriptionStatuses(originalTransactionId, null);
        return Optional.ofNullable(response.getData()).orElseGet(List::of).stream()
                .flatMap(group -> Optional.ofNullable(group.getLastTransactions()).orElseGet(List::of).stream())
                .filter(item -> originalTransactionId.equals(item.getOriginalTransactionId()))
                .findFirst()
                .map(LastTransactionsItem::getStatus)
                .map(BillingReconciliationJob::mapAppleStatus)
                .orElse(null);
    }

    private SubscriptionStatus fetchPlayStatus(String purchaseToken) throws java.io.IOException {
        SubscriptionPurchaseV2 purchase = playPurchaseClient.getSubscription(googleProperties.packageName(), purchaseToken);
        return mapPlayStatus(purchase.getSubscriptionState());
    }

    /** Stripe's own status strings — mirrors {@code StripeWebhookController.mapStatus} (`64` Prompt 5). */
    private static SubscriptionStatus mapStripeStatus(String stripeStatus) {
        if (stripeStatus == null) {
            return null;
        }
        return switch (stripeStatus) {
            case "trialing" -> SubscriptionStatus.TRIALING;
            case "active" -> SubscriptionStatus.ACTIVE;
            case "past_due" -> SubscriptionStatus.PAST_DUE;
            default -> TERMINAL_STRIPE_STATUSES.contains(stripeStatus) ? SubscriptionStatus.CANCELED : null;
        };
    }

    /**
     * {@code BILLING_GRACE_PERIOD} still counts as entitled — same treatment as
     * Play's {@code IN_GRACE_PERIOD} below. {@code REVOKED} maps to {@code
     * CANCELED}, not {@code REFUNDED}: Apple's status enum doesn't distinguish a
     * refund from a Family Sharing access loss at this granularity, so this stays
     * consistent with {@code AppStoreWebhookController}'s own {@code REVOKE} ->
     * {@code CANCELED} judgment call (`64` Prompt 10) rather than presuming a refund.
     */
    private static SubscriptionStatus mapAppleStatus(Status status) {
        return switch (status) {
            case ACTIVE, BILLING_GRACE_PERIOD -> SubscriptionStatus.ACTIVE;
            case BILLING_RETRY -> SubscriptionStatus.PAST_DUE;
            case EXPIRED -> SubscriptionStatus.EXPIRED;
            case REVOKED -> SubscriptionStatus.CANCELED;
        };
    }

    /** Mirrors {@code StoreBillingServiceImpl.mapPlayStatus} (`64` Prompt 9). */
    private static SubscriptionStatus mapPlayStatus(String subscriptionState) {
        if (PLAY_ACTIVE_STATES.contains(subscriptionState)) {
            return SubscriptionStatus.ACTIVE;
        }
        if (PLAY_PAST_DUE_STATES.contains(subscriptionState)) {
            return SubscriptionStatus.PAST_DUE;
        }
        if ("SUBSCRIPTION_STATE_CANCELED".equals(subscriptionState)) {
            return SubscriptionStatus.CANCELED;
        }
        // SUBSCRIPTION_STATE_EXPIRED, _PENDING, _PENDING_PURCHASE_CANCELED, _UNSPECIFIED, null: no entitlement.
        return SubscriptionStatus.EXPIRED;
    }

    // --- §7 step 3: trial expiry (`64` Prompt 7) --------------------------------------

    private void expireStaleTrials() {
        List<Subscription> staleTrials = subscriptionRepository.findByStatusAndTrialEndsAtBefore(
                SubscriptionStatus.TRIALING, clock.instant());
        staleTrials.forEach(trial -> subscriptionWriter.expireTrial(trial.getId()));
        if (!staleTrials.isEmpty()) {
            log.info("Expired {} stale trainer trial(s)", staleTrials.size());
        }
    }
}

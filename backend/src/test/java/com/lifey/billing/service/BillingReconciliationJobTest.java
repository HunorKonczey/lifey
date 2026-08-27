package com.lifey.billing.service;

import com.apple.itunes.storekit.model.Environment;
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
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.MockedStatic;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Pageable;

import java.io.IOException;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mockStatic;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * `64` Prompt 7's trial-expiry step (§7 point 3, unchanged here) plus Prompt
 * 11's *Verify* line: "a test where the local row says ACTIVE and the
 * provider says CANCELED -> the job corrects it and logs a WARN; a test that
 * the per-run cap is honoured." Stripe's static SDK call is stubbed via
 * {@link MockedStatic}, matching {@code StripeBillingServiceImplTest}'s
 * precedent; Play goes through the already-mockable {@link PlayPurchaseClient}
 * seam. Apple is deliberately not exercised here the same way — {@code
 * AppStoreServerAPIClient} parses its signing key eagerly at construction, so
 * a real key would be needed the way {@link AppleTestChain} supplies one for
 * JWS verification; the failure-is-swallowed path is still covered via Play.
 */
@ExtendWith(MockitoExtension.class)
class BillingReconciliationJobTest {

    private static final Instant NOW = Instant.parse("2026-06-15T03:30:00Z");
    private static final String PACKAGE_NAME = "com.lifey.app";

    private static final BillingProperties BILLING_PROPERTIES = new BillingProperties(true, 30, 5, 7, 200);
    private static final StripeProperties STRIPE_PROPERTIES = new StripeProperties(
            "sk_test_123", "whsec_test_123", "https://lifey.hu/success", "https://lifey.hu/cancel",
            "https://lifey.hu/portal", "p1", "p2", "p3", "p4", "p5", "p6");
    /** Blank Apple credentials, matching every other billing test's precedent — the App Store branch isn't exercised here (see class javadoc). */
    private static final AppleProperties APPLE_PROPERTIES = new AppleProperties(PACKAGE_NAME, 1234L, Environment.SANDBOX, "", "", "");
    private static final GoogleProperties GOOGLE_PROPERTIES = new GoogleProperties(PACKAGE_NAME, "", "", "");

    @Mock
    SubscriptionRepository subscriptionRepository;

    @Mock
    SubscriptionWriter subscriptionWriter;

    @Mock
    PlayPurchaseClient playPurchaseClient;

    private final SimpleMeterRegistry meterRegistry = new SimpleMeterRegistry();

    private BillingReconciliationJob job() {
        return job(BILLING_PROPERTIES);
    }

    private BillingReconciliationJob job(BillingProperties billingProperties) {
        return new BillingReconciliationJob(subscriptionRepository, subscriptionWriter, billingProperties,
                STRIPE_PROPERTIES, APPLE_PROPERTIES, GOOGLE_PROPERTIES, playPurchaseClient, meterRegistry,
                Clock.fixed(NOW, ZoneOffset.UTC));
    }

    private void noStaleTrials() {
        when(subscriptionRepository.findByStatusAndTrialEndsAtBefore(SubscriptionStatus.TRIALING, NOW))
                .thenReturn(List.of());
    }

    private void noReconciliationCandidates() {
        when(subscriptionRepository.findByStatusInAndProviderSubscriptionIdIsNotNull(any(), any()))
                .thenReturn(List.of());
    }

    private static Subscription subscription(Long id, SubscriptionProvider provider, SubscriptionStatus status, String providerSubscriptionId) {
        Subscription subscription = new Subscription();
        subscription.setId(id);
        subscription.setProvider(provider);
        subscription.setStatus(status);
        subscription.setProviderSubscriptionId(providerSubscriptionId);
        return subscription;
    }

    // --- Trial expiry (64 Prompt 7, unchanged by Prompt 11) --------------------------

    @Test
    void run_expiresEveryTrialPastItsTrialEndsAt() {
        noReconciliationCandidates();
        Subscription staleOne = new Subscription();
        staleOne.setId(1L);
        Subscription staleTwo = new Subscription();
        staleTwo.setId(2L);
        when(subscriptionRepository.findByStatusAndTrialEndsAtBefore(SubscriptionStatus.TRIALING, NOW))
                .thenReturn(List.of(staleOne, staleTwo));

        job().run();

        verify(subscriptionWriter).expireTrial(1L);
        verify(subscriptionWriter).expireTrial(2L);
    }

    @Test
    void run_doesNothingWhenNoTrialsAreStale() {
        noReconciliationCandidates();
        noStaleTrials();

        job().run();

        verify(subscriptionWriter, never()).expireTrial(any());
    }

    // --- Provider re-fetch, diff-and-correct, metrics (64 Prompt 11) -----------------

    @Test
    void run_localActiveButStripeSaysCanceled_correctsAndEmitsMetrics() {
        noStaleTrials();
        Subscription local = subscription(10L, SubscriptionProvider.STRIPE, SubscriptionStatus.ACTIVE, "sub_abc123");
        when(subscriptionRepository.findByStatusInAndProviderSubscriptionIdIsNotNull(any(), any()))
                .thenReturn(List.of(local));

        com.stripe.model.Subscription providerTruth = new com.stripe.model.Subscription();
        providerTruth.setStatus("canceled");

        try (MockedStatic<com.stripe.model.Subscription> mocked = mockStatic(com.stripe.model.Subscription.class)) {
            mocked.when(() -> com.stripe.model.Subscription.retrieve(eq("sub_abc123"), any(RequestOptions.class)))
                    .thenReturn(providerTruth);

            job().run();
        }

        verify(subscriptionWriter).markStatus(SubscriptionProvider.STRIPE, "sub_abc123", SubscriptionStatus.CANCELED);
        assertThat(meterRegistry.get("billing.reconciliation.rows_checked").tag("provider", "STRIPE").counter().count())
                .isEqualTo(1.0);
        assertThat(meterRegistry.get("billing.reconciliation.rows_corrected").tag("provider", "STRIPE").counter().count())
                .isEqualTo(1.0);
    }

    @Test
    void run_localStatusMatchesTheProvider_doesNotCorrectAnything() {
        noStaleTrials();
        Subscription local = subscription(10L, SubscriptionProvider.STRIPE, SubscriptionStatus.ACTIVE, "sub_abc123");
        when(subscriptionRepository.findByStatusInAndProviderSubscriptionIdIsNotNull(any(), any()))
                .thenReturn(List.of(local));

        com.stripe.model.Subscription providerTruth = new com.stripe.model.Subscription();
        providerTruth.setStatus("active");

        try (MockedStatic<com.stripe.model.Subscription> mocked = mockStatic(com.stripe.model.Subscription.class)) {
            mocked.when(() -> com.stripe.model.Subscription.retrieve(eq("sub_abc123"), any(RequestOptions.class)))
                    .thenReturn(providerTruth);

            job().run();
        }

        verify(subscriptionWriter, never()).markStatus(any(), any(), any());
        assertThat(meterRegistry.get("billing.reconciliation.rows_checked").tag("provider", "STRIPE").counter().count())
                .isEqualTo(1.0);
        assertThat(meterRegistry.get("billing.reconciliation.rows_corrected").tag("provider", "STRIPE").counter().count())
                .isEqualTo(0.0);
    }

    @Test
    void run_localActiveButPlaySaysCanceled_corrects() throws IOException {
        noStaleTrials();
        Subscription local = subscription(11L, SubscriptionProvider.PLAY_STORE, SubscriptionStatus.ACTIVE, "play-token-abc");
        when(subscriptionRepository.findByStatusInAndProviderSubscriptionIdIsNotNull(any(), any()))
                .thenReturn(List.of(local));
        SubscriptionPurchaseV2 purchase = new SubscriptionPurchaseV2();
        purchase.setSubscriptionState("SUBSCRIPTION_STATE_CANCELED");
        when(playPurchaseClient.getSubscription(PACKAGE_NAME, "play-token-abc")).thenReturn(purchase);

        job().run();

        verify(subscriptionWriter).markStatus(SubscriptionProvider.PLAY_STORE, "play-token-abc", SubscriptionStatus.CANCELED);
    }

    @Test
    void run_providerFetchFailure_isSwallowed_rowIsSkippedNotCorrected() throws IOException {
        noStaleTrials();
        Subscription local = subscription(12L, SubscriptionProvider.PLAY_STORE, SubscriptionStatus.ACTIVE, "play-token-down");
        when(subscriptionRepository.findByStatusInAndProviderSubscriptionIdIsNotNull(any(), any()))
                .thenReturn(List.of(local));
        when(playPurchaseClient.getSubscription(PACKAGE_NAME, "play-token-down")).thenThrow(new IOException("Play API down"));

        job().run();

        verify(subscriptionWriter, never()).markStatus(any(), any(), any());
        assertThat(meterRegistry.get("billing.reconciliation.rows_checked").tag("provider", "PLAY_STORE").counter().count())
                .isEqualTo(1.0);
        assertThat(meterRegistry.get("billing.reconciliation.rows_corrected").tag("provider", "PLAY_STORE").counter().count())
                .isEqualTo(0.0);
    }

    @Test
    void run_compProvider_isNeverSentToAVendor() {
        noStaleTrials();
        Subscription local = subscription(13L, SubscriptionProvider.COMP, SubscriptionStatus.ACTIVE, "comp-grant-1");
        when(subscriptionRepository.findByStatusInAndProviderSubscriptionIdIsNotNull(any(), any()))
                .thenReturn(List.of(local));

        job().run();

        verify(subscriptionWriter, never()).markStatus(any(), any(), any());
    }

    // --- Per-run cap (64 §7's rate limit) ---------------------------------------------

    @Test
    void run_perRunCapIsHonoured() {
        noStaleTrials();
        noReconciliationCandidates();

        job(new BillingProperties(true, 30, 5, 7, 25)).run();

        ArgumentCaptor<Pageable> pageableCaptor = ArgumentCaptor.forClass(Pageable.class);
        verify(subscriptionRepository).findByStatusInAndProviderSubscriptionIdIsNotNull(any(), pageableCaptor.capture());
        assertThat(pageableCaptor.getValue().getPageSize()).isEqualTo(25);
    }
}

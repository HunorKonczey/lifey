package com.lifey.billing.service;

import com.lifey.billing.BillingProperties;
import com.lifey.billing.dto.EntitlementResponse;
import com.lifey.billing.dto.EntitlementSource;
import com.lifey.billing.dto.EntitlementTier;
import com.lifey.billing.entity.Subscription;
import com.lifey.billing.entity.SubscriptionProvider;
import com.lifey.billing.entity.SubscriptionStatus;
import com.lifey.billing.entity.TrainerPlan;
import com.lifey.billing.repository.SubscriptionRepository;
import com.lifey.trainer.TrainerClientRepository;
import com.lifey.trainer.TrainerClientStatus;
import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.HashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Table-driven over the resolution order in
 * docs/landing_page/63-monetization-strategy-plan.md §3 and the edge cases in
 * §7.1–7.4 — "the single highest-value test in the whole feature" per that
 * doc's §10.
 */
@ExtendWith(MockitoExtension.class)
class EntitlementServiceImplTest {

    private static final Instant NOW = Instant.parse("2026-08-27T10:00:00Z");
    private static final Long USER_ID = 1L;
    private static final Long TRAINER_ID = 2L;

    private static final BillingProperties ENABLED = new BillingProperties(true, 30, 5, 7, 200);
    private static final BillingProperties DISABLED = new BillingProperties(false, 30, 5, 7, 200);

    @Mock
    UserRepository userRepository;

    @Mock
    SubscriptionRepository subscriptionRepository;

    @Mock
    TrainerClientRepository trainerClientRepository;

    @Mock
    AiUsageCounterService aiUsageCounterService;

    Clock clock;

    @BeforeEach
    void setUp() {
        clock = Clock.fixed(NOW, ZoneOffset.UTC);
    }

    private EntitlementServiceImpl service(BillingProperties properties) {
        return new EntitlementServiceImpl(userRepository, subscriptionRepository, trainerClientRepository,
                properties, aiUsageCounterService, clock);
    }

    private User user(Long id, Role... roles) {
        User user = new User();
        user.setId(id);
        user.setRoles(new HashSet<>(Set.of(roles)));
        return user;
    }

    private Subscription subscription(Long ownerId, SubscriptionProvider provider, SubscriptionStatus status) {
        Subscription subscription = new Subscription();
        User owner = new User();
        owner.setId(ownerId);
        subscription.setUser(owner);
        subscription.setProvider(provider);
        subscription.setStatus(status);
        return subscription;
    }

    // --- 1. Rollback switch -------------------------------------------------

    @Test
    void billingDisabled_returnsOpenCompForEveryone_regardlessOfSubscriptions() {
        when(userRepository.findById(USER_ID)).thenReturn(Optional.of(user(USER_ID, Role.ROLE_USER)));
        when(subscriptionRepository.findByUserId(USER_ID))
                .thenReturn(List.of(subscription(USER_ID, SubscriptionProvider.PLAY_STORE, SubscriptionStatus.CANCELED)));

        EntitlementResponse response = service(DISABLED).resolve(USER_ID);

        assertThat(response.tier()).isEqualTo(EntitlementTier.PRO);
        assertThat(response.source()).isEqualTo(EntitlementSource.COMP);
        assertThat(response.degraded()).isFalse();
        assertThat(response.trainer()).isNull();
    }

    // --- Unknown user ---------------------------------------------------------

    @Test
    void unknownUser_resolvesToWellFormedFree() {
        when(userRepository.findById(USER_ID)).thenReturn(Optional.empty());

        EntitlementResponse response = service(ENABLED).resolve(USER_ID);

        assertThat(response.tier()).isEqualTo(EntitlementTier.FREE);
        assertThat(response.source()).isEqualTo(EntitlementSource.NONE);
        assertThat(response.trainer()).isNull();
        assertThat(response.degraded()).isFalse();
    }

    // --- 2. Resolution order item 1: super admin / comp ------------------------

    @Test
    void superAdmin_resolvesToComp_withNoSubscriptionRows() {
        when(userRepository.findById(USER_ID)).thenReturn(Optional.of(user(USER_ID, Role.ROLE_USER, Role.ROLE_SUPER_ADMIN)));
        when(subscriptionRepository.findByUserId(USER_ID)).thenReturn(List.of());

        EntitlementResponse response = service(ENABLED).resolve(USER_ID);

        assertThat(response.tier()).isEqualTo(EntitlementTier.PRO);
        assertThat(response.source()).isEqualTo(EntitlementSource.COMP);
    }

    @Test
    void compSubscriptionRow_resolvesToComp() {
        when(userRepository.findById(USER_ID)).thenReturn(Optional.of(user(USER_ID, Role.ROLE_USER)));
        when(subscriptionRepository.findByUserId(USER_ID))
                .thenReturn(List.of(subscription(USER_ID, SubscriptionProvider.COMP, SubscriptionStatus.ACTIVE)));

        EntitlementResponse response = service(ENABLED).resolve(USER_ID);

        assertThat(response.tier()).isEqualTo(EntitlementTier.PRO);
        assertThat(response.source()).isEqualTo(EntitlementSource.COMP);
    }

    // --- 3. Resolution order item 2: own active paid subscription --------------

    @Test
    void ownActiveAppStoreSubscription_resolvesToProAppStore() {
        when(userRepository.findById(USER_ID)).thenReturn(Optional.of(user(USER_ID, Role.ROLE_USER)));
        when(subscriptionRepository.findByUserId(USER_ID))
                .thenReturn(List.of(subscription(USER_ID, SubscriptionProvider.APP_STORE, SubscriptionStatus.ACTIVE)));

        EntitlementResponse response = service(ENABLED).resolve(USER_ID);

        assertThat(response.tier()).isEqualTo(EntitlementTier.PRO);
        assertThat(response.source()).isEqualTo(EntitlementSource.APP_STORE);
        assertThat(response.historyDays()).isNull();
        assertThat(response.aiCreditsRemaining()).isNull();
        assertThat(response.adsEnabled()).isFalse();
    }

    @Test
    void ownPastDueStripeSubscription_staysProThroughDunning() {
        // 63 §7.5: past_due keeps full access through the Smart Retries window.
        when(userRepository.findById(USER_ID)).thenReturn(Optional.of(user(USER_ID, Role.ROLE_USER)));
        when(subscriptionRepository.findByUserId(USER_ID))
                .thenReturn(List.of(subscription(USER_ID, SubscriptionProvider.STRIPE, SubscriptionStatus.PAST_DUE)));

        EntitlementResponse response = service(ENABLED).resolve(USER_ID);

        assertThat(response.tier()).isEqualTo(EntitlementTier.PRO);
        assertThat(response.source()).isEqualTo(EntitlementSource.STRIPE);
    }

    @Test
    void ownCanceledSubscriptionWithNoSponsor_fallsThroughToFree() {
        when(userRepository.findById(USER_ID)).thenReturn(Optional.of(user(USER_ID, Role.ROLE_USER)));
        when(subscriptionRepository.findByUserId(USER_ID))
                .thenReturn(List.of(subscription(USER_ID, SubscriptionProvider.PLAY_STORE, SubscriptionStatus.CANCELED)));
        when(subscriptionRepository.findSponsoringSubscriptionsForActiveClient(USER_ID)).thenReturn(List.of());

        EntitlementResponse response = service(ENABLED).resolve(USER_ID);

        assertThat(response.tier()).isEqualTo(EntitlementTier.FREE);
        assertThat(response.source()).isEqualTo(EntitlementSource.NONE);
        assertThat(response.historyDays()).isEqualTo(30);
        assertThat(response.aiCreditsRemaining()).isEqualTo(5);
        assertThat(response.adsEnabled()).isTrue();
    }

    // --- 64 Prompt 12: aiCreditsRemaining reflects real ai_usage_counter usage -----

    @Test
    void freeUser_aiCreditsRemaining_subtractsActualUsageThisMonth() {
        when(userRepository.findById(USER_ID)).thenReturn(Optional.of(user(USER_ID, Role.ROLE_USER)));
        when(subscriptionRepository.findByUserId(USER_ID)).thenReturn(List.of());
        when(subscriptionRepository.findSponsoringSubscriptionsForActiveClient(USER_ID)).thenReturn(List.of());
        when(aiUsageCounterService.usedThisMonth(USER_ID)).thenReturn(2);

        EntitlementResponse response = service(ENABLED).resolve(USER_ID);

        assertThat(response.aiCreditsRemaining()).isEqualTo(3);
    }

    @Test
    void freeUser_usageAtOrOverTheLimit_clampsAiCreditsRemainingAtZero() {
        when(userRepository.findById(USER_ID)).thenReturn(Optional.of(user(USER_ID, Role.ROLE_USER)));
        when(subscriptionRepository.findByUserId(USER_ID)).thenReturn(List.of());
        when(subscriptionRepository.findSponsoringSubscriptionsForActiveClient(USER_ID)).thenReturn(List.of());
        when(aiUsageCounterService.usedThisMonth(USER_ID)).thenReturn(9);

        EntitlementResponse response = service(ENABLED).resolve(USER_ID);

        assertThat(response.aiCreditsRemaining()).isZero();
    }

    // --- 4. Resolution order item 3: sponsorship --------------------------------

    @Test
    void sponsoredByActiveTrainer_resolvesToTrainerSponsored() {
        when(userRepository.findById(USER_ID)).thenReturn(Optional.of(user(USER_ID, Role.ROLE_USER)));
        when(subscriptionRepository.findByUserId(USER_ID)).thenReturn(List.of());
        when(subscriptionRepository.findSponsoringSubscriptionsForActiveClient(USER_ID))
                .thenReturn(List.of(subscription(TRAINER_ID, SubscriptionProvider.STRIPE, SubscriptionStatus.ACTIVE)));

        EntitlementResponse response = service(ENABLED).resolve(USER_ID);

        assertThat(response.tier()).isEqualTo(EntitlementTier.PRO);
        assertThat(response.source()).isEqualTo(EntitlementSource.TRAINER_SPONSORED);
    }

    @Test
    void sponsoredByTrialingTrainer_stillSponsors() {
        when(userRepository.findById(USER_ID)).thenReturn(Optional.of(user(USER_ID, Role.ROLE_USER)));
        when(subscriptionRepository.findByUserId(USER_ID)).thenReturn(List.of());
        when(subscriptionRepository.findSponsoringSubscriptionsForActiveClient(USER_ID))
                .thenReturn(List.of(subscription(TRAINER_ID, SubscriptionProvider.STRIPE, SubscriptionStatus.TRIALING)));

        EntitlementResponse response = service(ENABLED).resolve(USER_ID);

        assertThat(response.source()).isEqualTo(EntitlementSource.TRAINER_SPONSORED);
    }

    @Test
    void sponsoredByPastDueTrainer_stillSponsors() {
        // 63 §7.5: "Sponsored clients follow the trainer's state, so they keep Pro through dunning too."
        when(userRepository.findById(USER_ID)).thenReturn(Optional.of(user(USER_ID, Role.ROLE_USER)));
        when(subscriptionRepository.findByUserId(USER_ID)).thenReturn(List.of());
        when(subscriptionRepository.findSponsoringSubscriptionsForActiveClient(USER_ID))
                .thenReturn(List.of(subscription(TRAINER_ID, SubscriptionProvider.STRIPE, SubscriptionStatus.PAST_DUE)));

        EntitlementResponse response = service(ENABLED).resolve(USER_ID);

        assertThat(response.source()).isEqualTo(EntitlementSource.TRAINER_SPONSORED);
    }

    @Test
    void sponsorCanceled_notSponsored_fallsThroughToFree() {
        when(userRepository.findById(USER_ID)).thenReturn(Optional.of(user(USER_ID, Role.ROLE_USER)));
        when(subscriptionRepository.findByUserId(USER_ID)).thenReturn(List.of());
        when(subscriptionRepository.findSponsoringSubscriptionsForActiveClient(USER_ID))
                .thenReturn(List.of(subscription(TRAINER_ID, SubscriptionProvider.STRIPE, SubscriptionStatus.CANCELED)));

        EntitlementResponse response = service(ENABLED).resolve(USER_ID);

        assertThat(response.tier()).isEqualTo(EntitlementTier.FREE);
    }

    @Test
    void clientOfTwoTrainersOneLapsedOneActive_anySingleActiveSponsorIsEnough() {
        // 63 §7.2.
        when(userRepository.findById(USER_ID)).thenReturn(Optional.of(user(USER_ID, Role.ROLE_USER)));
        when(subscriptionRepository.findByUserId(USER_ID)).thenReturn(List.of());
        when(subscriptionRepository.findSponsoringSubscriptionsForActiveClient(USER_ID)).thenReturn(List.of(
                subscription(TRAINER_ID, SubscriptionProvider.STRIPE, SubscriptionStatus.CANCELED),
                subscription(3L, SubscriptionProvider.STRIPE, SubscriptionStatus.ACTIVE)));

        EntitlementResponse response = service(ENABLED).resolve(USER_ID);

        assertThat(response.tier()).isEqualTo(EntitlementTier.PRO);
        assertThat(response.source()).isEqualTo(EntitlementSource.TRAINER_SPONSORED);
    }

    @Test
    void trainerAlsoOwnClient_ownPaidTakesPrecedenceOverSponsorship_andSkipsTheSponsorQuery() {
        // 63 §7.1: "Both hold; §3 gives their own paid/trial state precedence,
        // and the sponsorship is irrelevant since they already have Pro."
        when(userRepository.findById(USER_ID)).thenReturn(Optional.of(user(USER_ID, Role.ROLE_USER, Role.ROLE_TRAINER)));
        when(subscriptionRepository.findByUserId(USER_ID))
                .thenReturn(List.of(subscription(USER_ID, SubscriptionProvider.APP_STORE, SubscriptionStatus.ACTIVE)));
        when(trainerClientRepository.countByTrainerIdAndStatus(USER_ID, TrainerClientStatus.ACTIVE)).thenReturn(0L);

        EntitlementResponse response = service(ENABLED).resolve(USER_ID);

        assertThat(response.source()).isEqualTo(EntitlementSource.APP_STORE);
        verify(subscriptionRepository, never()).findSponsoringSubscriptionsForActiveClient(any());
    }

    // --- 5. Resolution order item 4: own trainer trial --------------------------

    @Test
    void ownTrainerTrialStillInDate_resolvesToTrainerTrial() {
        Subscription trial = subscription(USER_ID, SubscriptionProvider.STRIPE, SubscriptionStatus.TRIALING);
        trial.setPlan(TrainerPlan.PRO);
        trial.setTrialEndsAt(NOW.plus(5, ChronoUnit.DAYS));

        when(userRepository.findById(USER_ID)).thenReturn(Optional.of(user(USER_ID, Role.ROLE_USER, Role.ROLE_TRAINER)));
        when(subscriptionRepository.findByUserId(USER_ID)).thenReturn(List.of(trial));
        when(trainerClientRepository.countByTrainerIdAndStatus(USER_ID, TrainerClientStatus.ACTIVE)).thenReturn(3L);

        EntitlementResponse response = service(ENABLED).resolve(USER_ID);

        assertThat(response.tier()).isEqualTo(EntitlementTier.PRO);
        assertThat(response.source()).isEqualTo(EntitlementSource.TRAINER_TRIAL);
        assertThat(response.expiresAt()).isEqualTo(trial.getTrialEndsAt());
        assertThat(response.trainer()).isNotNull();
        assertThat(response.trainer().plan()).isEqualTo(TrainerPlan.PRO);
        assertThat(response.trainer().status()).isEqualTo(SubscriptionStatus.TRIALING);
        assertThat(response.trainer().maxClients()).isEqualTo(25);
        assertThat(response.trainer().activeClients()).isEqualTo(3);
        assertThat(response.trainer().trialEndsAt()).isEqualTo(trial.getTrialEndsAt());
    }

    @Test
    void ownTrainerTrialExpiredButNotYetSwept_fallsThroughToFree() {
        // The reconciliation job (64 §7) expires stale TRIALING rows once a day —
        // resolve() must not grant Pro in the window before that sweep runs.
        Subscription staleTrial = subscription(USER_ID, SubscriptionProvider.STRIPE, SubscriptionStatus.TRIALING);
        staleTrial.setTrialEndsAt(NOW.minus(1, ChronoUnit.DAYS));

        when(userRepository.findById(USER_ID)).thenReturn(Optional.of(user(USER_ID, Role.ROLE_USER, Role.ROLE_TRAINER)));
        when(subscriptionRepository.findByUserId(USER_ID)).thenReturn(List.of(staleTrial));
        when(trainerClientRepository.countByTrainerIdAndStatus(USER_ID, TrainerClientStatus.ACTIVE)).thenReturn(0L);

        EntitlementResponse response = service(ENABLED).resolve(USER_ID);

        assertThat(response.tier()).isEqualTo(EntitlementTier.FREE);
        // The trainer block is independent, informational data — still present.
        assertThat(response.trainer()).isNotNull();
        assertThat(response.trainer().status()).isEqualTo(SubscriptionStatus.TRIALING);
    }

    // --- Trainer block presence --------------------------------------------------

    @Test
    void trainerBlock_isNullForAPlainUser() {
        when(userRepository.findById(USER_ID)).thenReturn(Optional.of(user(USER_ID, Role.ROLE_USER)));
        when(subscriptionRepository.findByUserId(USER_ID)).thenReturn(List.of());
        when(subscriptionRepository.findSponsoringSubscriptionsForActiveClient(USER_ID)).thenReturn(List.of());

        EntitlementResponse response = service(ENABLED).resolve(USER_ID);

        assertThat(response.trainer()).isNull();
        verify(trainerClientRepository, never()).countByTrainerIdAndStatus(anyLong(), any());
    }

    // --- Fail-open ----------------------------------------------------------------

    @Test
    void resolverFailure_failsOpenWithDegradedTrue() {
        when(userRepository.findById(USER_ID)).thenThrow(new RuntimeException("db unreachable"));

        EntitlementResponse response = service(ENABLED).resolve(USER_ID);

        assertThat(response.tier()).isEqualTo(EntitlementTier.PRO);
        assertThat(response.source()).isEqualTo(EntitlementSource.COMP);
        assertThat(response.degraded()).isTrue();
    }

    // --- Server timestamps ----------------------------------------------------------

    @Test
    void graceUntil_isCheckedAtPlusOfflineGraceDays() {
        when(userRepository.findById(USER_ID)).thenReturn(Optional.of(user(USER_ID, Role.ROLE_USER)));
        when(subscriptionRepository.findByUserId(USER_ID)).thenReturn(List.of());
        when(subscriptionRepository.findSponsoringSubscriptionsForActiveClient(USER_ID)).thenReturn(List.of());

        EntitlementResponse response = service(ENABLED).resolve(USER_ID);

        assertThat(response.checkedAt()).isEqualTo(NOW);
        assertThat(response.graceUntil()).isEqualTo(NOW.plus(7, ChronoUnit.DAYS));
    }
}

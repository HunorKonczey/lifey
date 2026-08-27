package com.lifey.billing.service;

import com.lifey.billing.entity.Subscription;
import com.lifey.billing.entity.SubscriptionProvider;
import com.lifey.billing.entity.SubscriptionStatus;
import com.lifey.billing.entity.TrainerPlan;
import com.lifey.billing.repository.ProcessedBillingEventRepository;
import com.lifey.billing.repository.SubscriptionRepository;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** {@link SubscriptionWriter#startTrainerTrial} and {@link SubscriptionWriter#expireTrial} — 64 §4.1, §7 step 3. */
@ExtendWith(MockitoExtension.class)
class SubscriptionWriterTest {

    private static final Long USER_ID = 1L;
    private static final Instant TRIAL_ENDS_AT = Instant.parse("2026-06-15T09:00:00Z");

    @Mock
    SubscriptionRepository subscriptionRepository;

    @Mock
    ProcessedBillingEventRepository processedBillingEventRepository;

    @Mock
    UserRepository userRepository;

    @InjectMocks
    SubscriptionWriter writer;

    @Test
    void startTrainerTrial_createsATrialingProRow() {
        User user = new User();
        user.setId(USER_ID);
        when(userRepository.findById(USER_ID)).thenReturn(Optional.of(user));
        when(subscriptionRepository.findByUserIdAndProvider(USER_ID, SubscriptionProvider.STRIPE)).thenReturn(Optional.empty());

        writer.startTrainerTrial(USER_ID, TrainerPlan.PRO, TRIAL_ENDS_AT);

        ArgumentCaptor<Subscription> captor = ArgumentCaptor.forClass(Subscription.class);
        verify(subscriptionRepository).save(captor.capture());
        Subscription saved = captor.getValue();
        assertThat(saved.getProvider()).isEqualTo(SubscriptionProvider.STRIPE);
        assertThat(saved.getStatus()).isEqualTo(SubscriptionStatus.TRIALING);
        assertThat(saved.getPlan()).isEqualTo(TrainerPlan.PRO);
        assertThat(saved.getTrialEndsAt()).isEqualTo(TRIAL_ENDS_AT);
    }

    @Test
    void startTrainerTrial_doesNothingWhenATrainerAlreadyHasAStripeRow() {
        // A re-grant after a revoke must never reset an existing paid subscription (history is kept, 64 §4.1).
        User user = new User();
        user.setId(USER_ID);
        when(userRepository.findById(USER_ID)).thenReturn(Optional.of(user));
        Subscription existing = new Subscription();
        existing.setStatus(SubscriptionStatus.ACTIVE);
        when(subscriptionRepository.findByUserIdAndProvider(USER_ID, SubscriptionProvider.STRIPE)).thenReturn(Optional.of(existing));

        writer.startTrainerTrial(USER_ID, TrainerPlan.PRO, TRIAL_ENDS_AT);

        verify(subscriptionRepository, never()).save(any());
    }

    @Test
    void startTrainerTrial_skipsUnknownUser() {
        when(userRepository.findById(USER_ID)).thenReturn(Optional.empty());

        writer.startTrainerTrial(USER_ID, TrainerPlan.PRO, TRIAL_ENDS_AT);

        verify(subscriptionRepository, never()).save(any());
    }

    @Test
    void expireTrial_flipsATrialingRowToExpired() {
        Subscription trial = new Subscription();
        trial.setId(9L);
        trial.setStatus(SubscriptionStatus.TRIALING);
        when(subscriptionRepository.findById(9L)).thenReturn(Optional.of(trial));

        writer.expireTrial(9L);

        assertThat(trial.getStatus()).isEqualTo(SubscriptionStatus.EXPIRED);
        verify(subscriptionRepository).save(trial);
    }

    @Test
    void expireTrial_isANoOpIfTheRowIsNoLongerTrialing() {
        // e.g. the trainer upgraded between the job's read and this call.
        Subscription noLongerTrialing = new Subscription();
        noLongerTrialing.setId(9L);
        noLongerTrialing.setStatus(SubscriptionStatus.ACTIVE);
        when(subscriptionRepository.findById(9L)).thenReturn(Optional.of(noLongerTrialing));

        writer.expireTrial(9L);

        assertThat(noLongerTrialing.getStatus()).isEqualTo(SubscriptionStatus.ACTIVE);
        verify(subscriptionRepository, never()).save(any());
    }
}

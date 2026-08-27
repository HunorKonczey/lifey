package com.lifey.billing.service;

import com.lifey.billing.BillingProperties;
import com.lifey.billing.TrainerBillingState;
import com.lifey.billing.entity.Subscription;
import com.lifey.billing.entity.SubscriptionProvider;
import com.lifey.billing.entity.SubscriptionStatus;
import com.lifey.billing.entity.TrainerPlan;
import com.lifey.billing.exception.SeatLimitExceededException;
import com.lifey.billing.repository.SubscriptionRepository;
import com.lifey.trainer.TrainerClientRepository;
import com.lifey.trainer.TrainerClientStatus;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** Table-driven over 64 §4.4 — which {@link SubscriptionStatus} lets a trainer invite/assign, and the OVER_LIMIT boundary. */
@ExtendWith(MockitoExtension.class)
class SeatLimitServiceImplTest {

    private static final Long TRAINER_ID = 1L;
    private static final BillingProperties ENABLED = new BillingProperties(true, 30, 5, 7, 200);
    private static final BillingProperties DISABLED = new BillingProperties(false, 30, 5, 7, 200);

    @Mock
    SubscriptionRepository subscriptionRepository;

    @Mock
    TrainerClientRepository trainerClientRepository;

    private SeatLimitServiceImpl service(BillingProperties properties) {
        return new SeatLimitServiceImpl(subscriptionRepository, trainerClientRepository, properties);
    }

    private Subscription subscription(SubscriptionStatus status, TrainerPlan plan) {
        Subscription subscription = new Subscription();
        subscription.setProvider(SubscriptionProvider.STRIPE);
        subscription.setStatus(status);
        subscription.setPlan(plan);
        return subscription;
    }

    private void stubSubscription(Optional<Subscription> subscription) {
        when(subscriptionRepository.findByUserIdAndProvider(TRAINER_ID, SubscriptionProvider.STRIPE))
                .thenReturn(subscription);
    }

    // --- activeClientCount --------------------------------------------------------

    @Test
    void activeClientCount_delegatesToTheOneCanonicalRepositoryMethod() {
        when(trainerClientRepository.countByTrainerIdAndStatus(TRAINER_ID, TrainerClientStatus.ACTIVE)).thenReturn(4L);

        assertThat(service(ENABLED).activeClientCount(TRAINER_ID)).isEqualTo(4);
    }

    // --- 64 §4.4: which statuses allow inviting/assigning --------------------------

    @ParameterizedTest
    @EnumSource(value = SubscriptionStatus.class, names = {"TRIALING", "ACTIVE", "PAST_DUE"})
    void entitlingStatuses_underTheLimit_areOk(SubscriptionStatus status) {
        stubSubscription(Optional.of(subscription(status, TrainerPlan.STARTER)));
        lenient().when(trainerClientRepository.countByTrainerIdAndStatus(TRAINER_ID, TrainerClientStatus.ACTIVE)).thenReturn(2L);

        SeatLimitServiceImpl service = service(ENABLED);

        assertThat(service.state(TRAINER_ID)).isEqualTo(TrainerBillingState.OK);
        assertThat(service.canAcquireClient(TRAINER_ID)).isTrue();
    }

    @ParameterizedTest
    @EnumSource(value = SubscriptionStatus.class, names = {"CANCELED", "EXPIRED", "REFUNDED"})
    void nonEntitlingStatuses_areRestricted_regardlessOfSeatCount(SubscriptionStatus status) {
        stubSubscription(Optional.of(subscription(status, TrainerPlan.STUDIO)));

        SeatLimitServiceImpl service = service(ENABLED);

        assertThat(service.state(TRAINER_ID)).isEqualTo(TrainerBillingState.RESTRICTED);
        assertThat(service.canAcquireClient(TRAINER_ID)).isFalse();
        verify(trainerClientRepository, never()).countByTrainerIdAndStatus(any(), any());
    }

    @Test
    void noSubscriptionRow_isRestricted() {
        stubSubscription(Optional.empty());

        assertThat(service(ENABLED).state(TRAINER_ID)).isEqualTo(TrainerBillingState.RESTRICTED);
    }

    // --- OVER_LIMIT boundary --------------------------------------------------------

    @Test
    void atExactlyMaxClients_isOk_butCannotAcquireAnother() {
        // Starter = 5 (TrainerPlan). Exactly full is not "over" anything yet.
        stubSubscription(Optional.of(subscription(SubscriptionStatus.ACTIVE, TrainerPlan.STARTER)));
        when(trainerClientRepository.countByTrainerIdAndStatus(TRAINER_ID, TrainerClientStatus.ACTIVE)).thenReturn(5L);

        SeatLimitServiceImpl service = service(ENABLED);

        assertThat(service.state(TRAINER_ID)).isEqualTo(TrainerBillingState.OK);
        assertThat(service.canAcquireClient(TRAINER_ID)).isFalse();
    }

    @Test
    void aboveMaxClients_isOverLimit_butSponsorshipStillHolds() {
        // 63 §7.6 / 64 §11.3: a Studio→Starter downgrade with more active clients than the new limit.
        stubSubscription(Optional.of(subscription(SubscriptionStatus.ACTIVE, TrainerPlan.STARTER)));
        when(trainerClientRepository.countByTrainerIdAndStatus(TRAINER_ID, TrainerClientStatus.ACTIVE)).thenReturn(12L);

        SeatLimitServiceImpl service = service(ENABLED);

        assertThat(service.state(TRAINER_ID)).isEqualTo(TrainerBillingState.OVER_LIMIT);
        assertThat(service.canAcquireClient(TRAINER_ID)).isFalse();
    }

    // --- assertCanAcquireClient --------------------------------------------------------

    @Test
    void assertCanAcquireClient_throwsWhenCannotAcquire() {
        stubSubscription(Optional.of(subscription(SubscriptionStatus.CANCELED, TrainerPlan.PRO)));

        assertThatThrownBy(() -> service(ENABLED).assertCanAcquireClient(TRAINER_ID))
                .isInstanceOf(SeatLimitExceededException.class);
    }

    @Test
    void assertCanAcquireClient_doesNotThrowWhenUnderLimit() {
        stubSubscription(Optional.of(subscription(SubscriptionStatus.ACTIVE, TrainerPlan.PRO)));
        when(trainerClientRepository.countByTrainerIdAndStatus(TRAINER_ID, TrainerClientStatus.ACTIVE)).thenReturn(1L);

        service(ENABLED).assertCanAcquireClient(TRAINER_ID);
    }

    // --- assertActiveState (64 §4.3: AssignmentController/ProgramAssignmentController/WorkoutScheduleController) ---

    @Test
    void assertActiveState_throwsWhenNotOk() {
        stubSubscription(Optional.of(subscription(SubscriptionStatus.CANCELED, TrainerPlan.PRO)));

        assertThatThrownBy(() -> service(ENABLED).assertActiveState(TRAINER_ID))
                .isInstanceOf(SeatLimitExceededException.class);
    }

    @Test
    void assertActiveState_throwsWhenOverLimit() {
        stubSubscription(Optional.of(subscription(SubscriptionStatus.ACTIVE, TrainerPlan.STARTER)));
        when(trainerClientRepository.countByTrainerIdAndStatus(TRAINER_ID, TrainerClientStatus.ACTIVE)).thenReturn(12L);

        assertThatThrownBy(() -> service(ENABLED).assertActiveState(TRAINER_ID))
                .isInstanceOf(SeatLimitExceededException.class);
    }

    @Test
    void assertActiveState_passesWhenOk() {
        stubSubscription(Optional.of(subscription(SubscriptionStatus.ACTIVE, TrainerPlan.PRO)));
        when(trainerClientRepository.countByTrainerIdAndStatus(TRAINER_ID, TrainerClientStatus.ACTIVE)).thenReturn(1L);

        assertThatCode(() -> service(ENABLED).assertActiveState(TRAINER_ID)).doesNotThrowAnyException();
    }

    // --- assertCanSendInvite (64 §4.3: TrainerInviteController) ---------------------------

    @Test
    void assertCanSendInvite_throwsWhenNotEntitling() {
        stubSubscription(Optional.of(subscription(SubscriptionStatus.CANCELED, TrainerPlan.PRO)));

        assertThatThrownBy(() -> service(ENABLED).assertCanSendInvite(TRAINER_ID))
                .isInstanceOf(SeatLimitExceededException.class);
        verify(trainerClientRepository, never()).countByTrainerIdAndStatusAndExpiresAtAfter(any(), any(), any());
    }

    @Test
    void assertCanSendInvite_countsPendingInvitesTowardTheLimit() {
        // 5-seat Starter plan, 3 active + 2 pending = at capacity already.
        stubSubscription(Optional.of(subscription(SubscriptionStatus.ACTIVE, TrainerPlan.STARTER)));
        when(trainerClientRepository.countByTrainerIdAndStatus(TRAINER_ID, TrainerClientStatus.ACTIVE)).thenReturn(3L);
        when(trainerClientRepository.countByTrainerIdAndStatusAndExpiresAtAfter(eq(TRAINER_ID), eq(TrainerClientStatus.PENDING), any()))
                .thenReturn(2L);

        assertThatThrownBy(() -> service(ENABLED).assertCanSendInvite(TRAINER_ID))
                .isInstanceOf(SeatLimitExceededException.class);
    }

    @Test
    void assertCanSendInvite_passesWhenActivePlusPendingUnderTheLimit() {
        stubSubscription(Optional.of(subscription(SubscriptionStatus.ACTIVE, TrainerPlan.STARTER)));
        when(trainerClientRepository.countByTrainerIdAndStatus(TRAINER_ID, TrainerClientStatus.ACTIVE)).thenReturn(2L);
        when(trainerClientRepository.countByTrainerIdAndStatusAndExpiresAtAfter(eq(TRAINER_ID), eq(TrainerClientStatus.PENDING), any()))
                .thenReturn(1L);

        assertThatCode(() -> service(ENABLED).assertCanSendInvite(TRAINER_ID)).doesNotThrowAnyException();
    }

    // --- assertCanAcquireClientForAccept (64 §4.3, 63 §7.6) --------------------------------

    @Test
    void assertCanAcquireClientForAccept_locksTheSubscriptionRow_beforeCounting() {
        Subscription locked = subscription(SubscriptionStatus.ACTIVE, TrainerPlan.STARTER);
        when(subscriptionRepository.lockTrainerSubscriptionForUpdate(TRAINER_ID)).thenReturn(Optional.of(locked));
        when(trainerClientRepository.countByTrainerIdAndStatus(TRAINER_ID, TrainerClientStatus.ACTIVE)).thenReturn(4L);

        assertThatCode(() -> service(ENABLED).assertCanAcquireClientForAccept(TRAINER_ID)).doesNotThrowAnyException();

        verify(subscriptionRepository, never()).findByUserIdAndProvider(any(), any());
    }

    @Test
    void assertCanAcquireClientForAccept_throwsAtCapacity() {
        Subscription locked = subscription(SubscriptionStatus.ACTIVE, TrainerPlan.STARTER);
        when(subscriptionRepository.lockTrainerSubscriptionForUpdate(TRAINER_ID)).thenReturn(Optional.of(locked));
        when(trainerClientRepository.countByTrainerIdAndStatus(TRAINER_ID, TrainerClientStatus.ACTIVE)).thenReturn(5L);

        assertThatThrownBy(() -> service(ENABLED).assertCanAcquireClientForAccept(TRAINER_ID))
                .isInstanceOf(SeatLimitExceededException.class);
    }

    @Test
    void assertCanAcquireClientForAccept_throwsWhenNoLockedSubscription() {
        when(subscriptionRepository.lockTrainerSubscriptionForUpdate(TRAINER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service(ENABLED).assertCanAcquireClientForAccept(TRAINER_ID))
                .isInstanceOf(SeatLimitExceededException.class);
    }

    // --- 64 §1 point 6: the rollback switch --------------------------------------------

    @Test
    void billingDisabled_everySeatCheckPasses() {
        SeatLimitServiceImpl service = service(DISABLED);

        assertThat(service.state(TRAINER_ID)).isEqualTo(TrainerBillingState.OK);
        assertThat(service.canAcquireClient(TRAINER_ID)).isTrue();
        service.assertCanAcquireClient(TRAINER_ID);
        assertThatCode(() -> service.assertActiveState(TRAINER_ID)).doesNotThrowAnyException();
        assertThatCode(() -> service.assertCanSendInvite(TRAINER_ID)).doesNotThrowAnyException();
        assertThatCode(() -> service.assertCanAcquireClientForAccept(TRAINER_ID)).doesNotThrowAnyException();
        verify(subscriptionRepository, never()).findByUserIdAndProvider(any(), any());
        verify(subscriptionRepository, never()).lockTrainerSubscriptionForUpdate(anyLong());
    }
}

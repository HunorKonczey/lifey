package com.lifey.billing.service;

import com.lifey.billing.BillingProperties;
import com.lifey.billing.TrainerBillingState;
import com.lifey.billing.entity.Subscription;
import com.lifey.billing.entity.SubscriptionProvider;
import com.lifey.billing.entity.SubscriptionStatus;
import com.lifey.billing.exception.SeatLimitExceededException;
import com.lifey.billing.repository.SubscriptionRepository;
import com.lifey.trainer.TrainerClientRepository;
import com.lifey.trainer.TrainerClientStatus;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.EnumSet;
import java.util.Set;

/**
 * The trainer state machine from docs/landing_page/64-billing-backend-plan.md
 * §4.2/§4.4. With {@code lifey.billing.enabled=false} every check passes and
 * {@link #state} is always {@code OK} — the same rollback switch
 * {@code EntitlementService} respects (§1 point 6).
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class SeatLimitServiceImpl implements SeatLimitService {

    /** 64 §4.4: the statuses that let a trainer invite/assign at all. */
    private static final Set<SubscriptionStatus> CAN_INVITE_STATUSES =
            EnumSet.of(SubscriptionStatus.TRIALING, SubscriptionStatus.ACTIVE, SubscriptionStatus.PAST_DUE);

    private final SubscriptionRepository subscriptionRepository;
    private final TrainerClientRepository trainerClientRepository;
    private final BillingProperties billingProperties;

    @Override
    public int activeClientCount(Long trainerId) {
        return (int) trainerClientRepository.countByTrainerIdAndStatus(trainerId, TrainerClientStatus.ACTIVE);
    }

    @Override
    public boolean canAcquireClient(Long trainerId) {
        if (!billingProperties.enabled()) {
            return true;
        }
        Subscription subscription = trainerSubscription(trainerId);
        if (subscription == null || subscription.getPlan() == null || !CAN_INVITE_STATUSES.contains(subscription.getStatus())) {
            return false;
        }
        return activeClientCount(trainerId) < subscription.getPlan().getMaxClients();
    }

    @Override
    public void assertCanAcquireClient(Long trainerId) {
        if (!canAcquireClient(trainerId)) {
            throw new SeatLimitExceededException("Trainer " + trainerId + " cannot acquire another client");
        }
    }

    @Override
    public TrainerBillingState state(Long trainerId) {
        if (!billingProperties.enabled()) {
            return TrainerBillingState.OK;
        }
        Subscription subscription = trainerSubscription(trainerId);
        if (subscription == null || subscription.getPlan() == null || !CAN_INVITE_STATUSES.contains(subscription.getStatus())) {
            return TrainerBillingState.RESTRICTED;
        }
        if (activeClientCount(trainerId) > subscription.getPlan().getMaxClients()) {
            return TrainerBillingState.OVER_LIMIT;
        }
        return TrainerBillingState.OK;
    }

    @Override
    public void assertCanSendInvite(Long trainerId) {
        if (!billingProperties.enabled()) {
            return;
        }
        Subscription subscription = trainerSubscription(trainerId);
        if (subscription == null || subscription.getPlan() == null || !CAN_INVITE_STATUSES.contains(subscription.getStatus())) {
            throw new SeatLimitExceededException("Trainer " + trainerId + " has no entitling subscription");
        }
        long pendingInvites = trainerClientRepository.countByTrainerIdAndStatusAndExpiresAtAfter(
                trainerId, TrainerClientStatus.PENDING, Instant.now());
        long committed = activeClientCount(trainerId) + pendingInvites;
        if (committed >= subscription.getPlan().getMaxClients()) {
            throw new SeatLimitExceededException(
                    "Trainer " + trainerId + " would exceed their seat limit (active clients + pending invites)");
        }
    }

    @Override
    @Transactional
    public void assertCanAcquireClientForAccept(Long trainerId) {
        if (!billingProperties.enabled()) {
            return;
        }
        Subscription subscription = subscriptionRepository.lockTrainerSubscriptionForUpdate(trainerId).orElse(null);
        if (subscription == null || subscription.getPlan() == null || !CAN_INVITE_STATUSES.contains(subscription.getStatus())) {
            throw new SeatLimitExceededException("Trainer " + trainerId + " has no entitling subscription");
        }
        if (activeClientCount(trainerId) >= subscription.getPlan().getMaxClients()) {
            throw new SeatLimitExceededException("Trainer " + trainerId + " seat limit reached");
        }
    }

    @Override
    public void assertActiveState(Long trainerId) {
        if (state(trainerId) != TrainerBillingState.OK) {
            throw new SeatLimitExceededException(
                    "Trainer " + trainerId + " billing state is not OK, cannot assign or schedule new content");
        }
    }

    private Subscription trainerSubscription(Long trainerId) {
        return subscriptionRepository.findByUserIdAndProvider(trainerId, SubscriptionProvider.STRIPE).orElse(null);
    }
}

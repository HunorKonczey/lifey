package com.lifey.billing;

import com.lifey.billing.entity.TrainerPlan;
import com.lifey.billing.service.SubscriptionWriter;
import com.lifey.superadmin.TrainerRoleGrantedEvent;
import lombok.RequiredArgsConstructor;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;

/**
 * Starts the 14-day trial the moment {@code ROLE_TRAINER} is actually
 * granted (docs/landing_page/64-billing-backend-plan.md §4.1). Plain {@code
 * @EventListener}, not {@code @TransactionalEventListener(AFTER_COMMIT)} —
 * same rationale as {@code ScheduleCancellationListener}: this must run
 * inside the same transaction as the grant itself, so the trial row and the
 * role are never observably out of sync.
 */
@Component
@RequiredArgsConstructor
class TrainerTrialListener {

    private static final Duration TRIAL_LENGTH = Duration.ofDays(14);

    private final SubscriptionWriter subscriptionWriter;
    private final Clock clock;

    @EventListener
    void onTrainerRoleGranted(TrainerRoleGrantedEvent event) {
        Instant trialEndsAt = clock.instant().plus(TRIAL_LENGTH);
        subscriptionWriter.startTrainerTrial(event.userId(), TrainerPlan.PRO, trialEndsAt);
    }
}

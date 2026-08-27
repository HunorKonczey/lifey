package com.lifey.billing;

import com.lifey.billing.entity.TrainerPlan;
import com.lifey.billing.service.SubscriptionWriter;
import com.lifey.superadmin.TrainerRoleGrantedEvent;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;

import static org.mockito.Mockito.verify;

/** 64 §4.1: the trial starts exactly 14 days from the grant moment. */
@ExtendWith(MockitoExtension.class)
class TrainerTrialListenerTest {

    private static final Long USER_ID = 42L;
    private static final Long ACTOR_ID = 7L;
    private static final Instant NOW = Instant.parse("2026-06-01T09:00:00Z");

    @Mock
    SubscriptionWriter subscriptionWriter;

    @Test
    void onTrainerRoleGranted_startsA14DayProTrial() {
        TrainerTrialListener listener = new TrainerTrialListener(subscriptionWriter, Clock.fixed(NOW, ZoneOffset.UTC));

        listener.onTrainerRoleGranted(new TrainerRoleGrantedEvent(USER_ID, ACTOR_ID));

        verify(subscriptionWriter).startTrainerTrial(USER_ID, TrainerPlan.PRO, Instant.parse("2026-06-15T09:00:00Z"));
    }
}

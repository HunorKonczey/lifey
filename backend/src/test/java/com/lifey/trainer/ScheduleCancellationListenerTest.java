package com.lifey.trainer;

import com.lifey.trainer.service.WorkoutScheduleService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.mockito.Mockito.verify;

@ExtendWith(MockitoExtension.class)
class ScheduleCancellationListenerTest {

    @Mock
    WorkoutScheduleService workoutScheduleService;

    @InjectMocks
    ScheduleCancellationListener listener;

    @Test
    void onTrainerClientRevoked_cancelsSchedulesForThePair() {
        listener.onTrainerClientRevoked(new TrainerClientRevokedEvent(1L, 2L));

        verify(workoutScheduleService).cancelActiveSchedulesForPair(1L, 2L);
    }
}

package com.lifey.auth;

import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.workout.exercise.Exercise;
import com.lifey.workout.exercise.ExerciseRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class StarterCatalogListenerTest {

    private static final Long USER_ID = 1L;

    @Mock
    ExerciseRepository exerciseRepository;

    @Mock
    UserRepository userRepository;

    @InjectMocks
    StarterCatalogListener listener;

    @BeforeEach
    void setUp() {
        when(userRepository.getReferenceById(USER_ID)).thenReturn(new User());
    }

    @Test
    void seedsTheStarterExerciseCatalogForTheNewUser() {
        listener.onUserRegistered(new UserRegisteredEvent(USER_ID));

        ArgumentCaptor<Exercise> captor = ArgumentCaptor.forClass(Exercise.class);
        verify(exerciseRepository, times(8)).save(captor.capture());
        assertThat(captor.getAllValues()).extracting(Exercise::getName).containsExactly(
                "Bench Press", "Squat", "Deadlift", "Overhead Press",
                "Barbell Row", "Pull Up", "Bicep Curl", "Plank");
        assertThat(captor.getAllValues()).allSatisfy(e -> assertThat(e.getUser()).isNotNull());
    }

    @Test
    void neverPropagatesFailuresToTheCaller() {
        when(userRepository.getReferenceById(USER_ID)).thenThrow(new RuntimeException("boom"));

        assertThatCode(() -> listener.onUserRegistered(new UserRegisteredEvent(USER_ID)))
                .doesNotThrowAnyException();

        verify(exerciseRepository, never()).save(any());
    }
}

package com.lifey.workout.session;

import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.workout.exercise.Exercise;
import com.lifey.workout.exercise.ExerciseRepository;
import com.lifey.workout.session.dto.ExerciseSetRequest;
import com.lifey.workout.session.dto.WorkoutSessionRequest;
import com.lifey.workout.session.dto.WorkoutSessionResponse;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class WorkoutSessionServiceImplTest {

    @Mock
    WorkoutSessionRepository sessionRepository;

    @Mock
    ExerciseRepository exerciseRepository;

    @InjectMocks
    WorkoutSessionServiceImpl service;

    @Test
    void create_resolvesExercisesAndMapsSets() {
        when(exerciseRepository.findById(1L)).thenReturn(Optional.of(exercise(1L, "Bench Press")));
        when(sessionRepository.save(any(WorkoutSession.class))).thenAnswer(inv -> {
            WorkoutSession s = inv.getArgument(0);
            s.setId(2L);
            return s;
        });
        Instant started = Instant.parse("2026-06-18T05:00:00Z");
        WorkoutSessionRequest request = new WorkoutSessionRequest(started, null,
                List.of(new ExerciseSetRequest(1L, 10, 60.0)));

        WorkoutSessionResponse result = service.create(request);

        assertThat(result.id()).isEqualTo(2L);
        assertThat(result.startedAt()).isEqualTo(started);
        assertThat(result.finishedAt()).isNull();
        assertThat(result.sets()).singleElement().satisfies(s -> {
            assertThat(s.exerciseId()).isEqualTo(1L);
            assertThat(s.exerciseName()).isEqualTo("Bench Press");
            assertThat(s.reps()).isEqualTo(10);
            assertThat(s.weight()).isEqualTo(60.0);
        });
    }

    @Test
    void create_throwsWhenExerciseMissing() {
        when(exerciseRepository.findById(99L)).thenReturn(Optional.empty());
        WorkoutSessionRequest request = new WorkoutSessionRequest(
                Instant.parse("2026-06-18T05:00:00Z"), null,
                List.of(new ExerciseSetRequest(99L, 5, 100.0)));

        assertThatThrownBy(() -> service.create(request))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessageContaining("Exercise not found: 99");
    }

    private static Exercise exercise(Long id, String name) {
        Exercise e = new Exercise();
        e.setId(id);
        e.setName(name);
        return e;
    }
}

package com.lifey.workout.session;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.workout.exercise.Exercise;
import com.lifey.workout.exercise.ExerciseRepository;
import com.lifey.workout.session.dto.ExerciseSetRequest;
import com.lifey.workout.session.dto.ExerciseSummary;
import com.lifey.workout.session.dto.WorkoutSessionRequest;
import com.lifey.workout.session.dto.WorkoutSessionResponse;
import org.junit.jupiter.api.BeforeEach;
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
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class WorkoutSessionServiceImplTest {

    private static final Long USER_ID = 1L;

    @Mock
    WorkoutSessionRepository sessionRepository;

    @Mock
    ExerciseRepository exerciseRepository;

    @Mock
    UserRepository userRepository;

    @Mock
    CurrentUserProvider currentUserProvider;

    @InjectMocks
    WorkoutSessionServiceImpl service;

    @BeforeEach
    void stubCurrentUser() {
        lenient().when(currentUserProvider.getUserId()).thenReturn(USER_ID);
        lenient().when(userRepository.getReferenceById(USER_ID)).thenReturn(new User());
    }

    @Test
    void create_resolvesPlannedExercisesAndSets() {
        when(exerciseRepository.findById(1L)).thenReturn(Optional.of(exercise(1L, "Bench Press")));
        when(exerciseRepository.findById(4L)).thenReturn(Optional.of(exercise(4L, "Overhead Press")));
        when(sessionRepository.save(any(WorkoutSession.class))).thenAnswer(inv -> {
            WorkoutSession s = inv.getArgument(0);
            s.setId(2L);
            return s;
        });
        Instant started = Instant.parse("2026-06-18T05:00:00Z");
        Instant performedAt = Instant.parse("2026-06-18T05:05:00Z");
        WorkoutSessionRequest request = new WorkoutSessionRequest(started, null,
                List.of(1L, 4L), List.of(new ExerciseSetRequest(1L, 10, 60.0, performedAt)),
                450.0, 132.0, "HK-UUID-1");

        WorkoutSessionResponse result = service.create(request);

        assertThat(result.id()).isEqualTo(2L);
        assertThat(result.startedAt()).isEqualTo(started);
        assertThat(result.exercises()).extracting(ExerciseSummary::exerciseId).containsExactly(1L, 4L);
        assertThat(result.sets()).singleElement().satisfies(s -> {
            assertThat(s.exerciseId()).isEqualTo(1L);
            assertThat(s.exerciseName()).isEqualTo("Bench Press");
            assertThat(s.reps()).isEqualTo(10);
            assertThat(s.weight()).isEqualTo(60.0);
            assertThat(s.performedAt()).isEqualTo(performedAt);
        });
        assertThat(result.activeCalories()).isEqualTo(450.0);
        assertThat(result.averageHeartRate()).isEqualTo(132.0);
        assertThat(result.healthWorkoutId()).isEqualTo("HK-UUID-1");
    }

    @Test
    void create_allowsAnEmptySessionWithNoPlannedExercisesOrSets() {
        when(sessionRepository.save(any(WorkoutSession.class))).thenAnswer(inv -> {
            WorkoutSession s = inv.getArgument(0);
            s.setId(5L);
            return s;
        });
        WorkoutSessionRequest request = new WorkoutSessionRequest(
                Instant.parse("2026-06-18T05:00:00Z"), null, List.of(), List.of(),
                null, null, null);

        WorkoutSessionResponse result = service.create(request);

        assertThat(result.id()).isEqualTo(5L);
        assertThat(result.exercises()).isEmpty();
        assertThat(result.sets()).isEmpty();
        assertThat(result.activeCalories()).isNull();
        assertThat(result.averageHeartRate()).isNull();
        assertThat(result.healthWorkoutId()).isNull();
    }

    @Test
    void create_throwsWhenPlannedExerciseMissing() {
        when(exerciseRepository.findById(99L)).thenReturn(Optional.empty());
        WorkoutSessionRequest request = new WorkoutSessionRequest(
                Instant.parse("2026-06-18T05:00:00Z"), null, List.of(99L), List.of(),
                null, null, null);

        assertThatThrownBy(() -> service.create(request))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessageContaining("Exercise not found: 99");
    }

    @Test
    void create_throwsWhenSetExerciseMissing() {
        when(exerciseRepository.findById(99L)).thenReturn(Optional.empty());
        WorkoutSessionRequest request = new WorkoutSessionRequest(
                Instant.parse("2026-06-18T05:00:00Z"), null,
                List.of(), List.of(new ExerciseSetRequest(99L, 5, 100.0,
                        Instant.parse("2026-06-18T05:05:00Z"))),
                null, null, null);

        assertThatThrownBy(() -> service.create(request))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessageContaining("Exercise not found: 99");
    }

    @Test
    void update_rebuildsPlannedExercisesAndSetsAndFinishesSession() {
        WorkoutSession existing = new WorkoutSession();
        existing.setId(3L);
        existing.setStartedAt(Instant.parse("2026-06-18T05:00:00Z"));
        WorkoutSessionExercise oldPlanned = new WorkoutSessionExercise();
        oldPlanned.setWorkoutSession(existing);
        oldPlanned.setExercise(exercise(2L, "Squat"));
        existing.getPlannedExercises().add(oldPlanned);
        ExerciseSet oldSet = new ExerciseSet();
        oldSet.setWorkoutSession(existing);
        oldSet.setExercise(exercise(2L, "Squat"));
        oldSet.setReps(5);
        oldSet.setWeight(100.0);
        oldSet.setPerformedAt(Instant.parse("2026-06-18T05:00:00Z"));
        existing.getSets().add(oldSet);

        when(sessionRepository.findByIdAndUserId(3L, USER_ID)).thenReturn(Optional.of(existing));
        when(exerciseRepository.findById(1L)).thenReturn(Optional.of(exercise(1L, "Bench Press")));
        Instant finished = Instant.parse("2026-06-18T06:00:00Z");
        WorkoutSessionRequest request = new WorkoutSessionRequest(
                Instant.parse("2026-06-18T05:00:00Z"), finished,
                List.of(1L), List.of(new ExerciseSetRequest(1L, 8, 70.0,
                        Instant.parse("2026-06-18T05:30:00Z"))),
                480.0, 140.0, "HK-UUID-2");

        WorkoutSessionResponse result = service.update(3L, request);

        assertThat(result.finishedAt()).isEqualTo(finished);
        assertThat(result.exercises()).singleElement().satisfies(e -> assertThat(e.exerciseId()).isEqualTo(1L));
        assertThat(result.sets()).singleElement().satisfies(s -> assertThat(s.reps()).isEqualTo(8));
        assertThat(existing.getPlannedExercises()).hasSize(1);
        assertThat(existing.getSets()).hasSize(1);
        assertThat(result.activeCalories()).isEqualTo(480.0);
        assertThat(result.averageHeartRate()).isEqualTo(140.0);
        assertThat(result.healthWorkoutId()).isEqualTo("HK-UUID-2");
    }

    @Test
    void update_throwsWhenMissing() {
        when(sessionRepository.findByIdAndUserId(99L, USER_ID)).thenReturn(Optional.empty());
        WorkoutSessionRequest request = new WorkoutSessionRequest(
                Instant.parse("2026-06-18T05:00:00Z"), null,
                List.of(), List.of(new ExerciseSetRequest(1L, 5, 50.0,
                        Instant.parse("2026-06-18T05:05:00Z"))),
                null, null, null);

        assertThatThrownBy(() -> service.update(99L, request))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void delete_throwsWhenMissing() {
        when(sessionRepository.existsByIdAndUserId(99L, USER_ID)).thenReturn(false);

        assertThatThrownBy(() -> service.delete(99L))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void delete_removesWhenExists() {
        when(sessionRepository.existsByIdAndUserId(3L, USER_ID)).thenReturn(true);

        service.delete(3L);

        verify(sessionRepository).deleteByIdAndUserId(3L, USER_ID);
    }

    private static Exercise exercise(Long id, String name) {
        Exercise e = new Exercise();
        e.setId(id);
        e.setName(name);
        return e;
    }
}

package com.lifey.workout.session.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.workout.exercise.Exercise;
import com.lifey.workout.exercise.ExerciseRepository;
import com.lifey.workout.session.ExerciseSet;
import com.lifey.workout.session.WorkoutSession;
import com.lifey.workout.session.WorkoutSessionExercise;
import com.lifey.workout.session.WorkoutSessionRepository;
import com.lifey.workout.session.dto.ExerciseSetRequest;
import com.lifey.workout.session.dto.ExerciseSummary;
import com.lifey.workout.session.dto.WorkoutSessionRequest;
import com.lifey.workout.session.dto.WorkoutSessionResponse;
import com.lifey.workout.template.WorkoutTemplate;
import com.lifey.workout.template.WorkoutTemplateRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.lenient;
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
    WorkoutTemplateRepository templateRepository;

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
                450.0, 132.0, "HK-UUID-1", null);

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
                null, null, null, null);

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
                null, null, null, null);

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
                null, null, null, null);

        assertThatThrownBy(() -> service.create(request))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessageContaining("Exercise not found: 99");
    }

    @Test
    void create_resolvesTemplateAndSnapshotsItsName() {
        when(templateRepository.findByIdAndUserId(7L, USER_ID))
                .thenReturn(Optional.of(template(7L, "Push Day")));
        when(sessionRepository.save(any(WorkoutSession.class))).thenAnswer(inv -> {
            WorkoutSession s = inv.getArgument(0);
            s.setId(6L);
            return s;
        });
        WorkoutSessionRequest request = new WorkoutSessionRequest(
                Instant.parse("2026-06-18T05:00:00Z"), null, List.of(), List.of(),
                null, null, null, 7L);

        WorkoutSessionResponse result = service.create(request);

        assertThat(result.templateId()).isEqualTo(7L);
        assertThat(result.templateName()).isEqualTo("Push Day");
    }

    @Test
    void create_throwsWhenTemplateMissing() {
        when(templateRepository.findByIdAndUserId(99L, USER_ID)).thenReturn(Optional.empty());
        WorkoutSessionRequest request = new WorkoutSessionRequest(
                Instant.parse("2026-06-18T05:00:00Z"), null, List.of(), List.of(),
                null, null, null, 99L);

        assertThatThrownBy(() -> service.create(request))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessageContaining("Workout template not found: 99");
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
                480.0, 140.0, "HK-UUID-2", null);

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
                null, null, null, null);

        assertThatThrownBy(() -> service.update(99L, request))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void delete_throwsWhenMissing() {
        when(sessionRepository.findByIdAndUserId(99L, USER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.delete(99L))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void delete_setsDeletedAtInsteadOfRemovingRow() {
        WorkoutSession existing = new WorkoutSession();
        existing.setId(3L);
        when(sessionRepository.findByIdAndUserId(3L, USER_ID)).thenReturn(Optional.of(existing));

        service.delete(3L);

        assertThat(existing.getDeletedAt()).isNotNull();
    }

    @Test
    void update_childOnlyEditBumpsParentUpdatedAt() {
        WorkoutSession existing = new WorkoutSession();
        existing.setId(3L);
        existing.setStartedAt(Instant.parse("2026-06-18T05:00:00Z"));
        existing.setUpdatedAt(Instant.parse("2026-06-18T05:00:00Z"));
        when(sessionRepository.findByIdAndUserId(3L, USER_ID)).thenReturn(Optional.of(existing));
        when(exerciseRepository.findById(1L)).thenReturn(Optional.of(exercise(1L, "Bench Press")));

        // Same startedAt/finishedAt/etc as before — only the sets differ.
        WorkoutSessionRequest request = new WorkoutSessionRequest(
                Instant.parse("2026-06-18T05:00:00Z"), null,
                List.of(), List.of(new ExerciseSetRequest(1L, 8, 70.0,
                Instant.parse("2026-06-18T05:30:00Z"))),
                null, null, null, null);

        service.update(3L, request);

        assertThat(existing.getUpdatedAt()).isAfter(Instant.parse("2026-06-18T05:00:00Z"));
    }

    @Test
    void findDelta_isUserScopedAndIncludesTombstones() {
        WorkoutSession deleted = new WorkoutSession();
        deleted.setId(2L);
        deleted.setDeletedAt(Instant.parse("2026-06-19T00:00:00Z"));

        Instant since = Instant.parse("2026-06-17T00:00:00Z");
        Pageable requested = PageRequest.of(0, 50);
        Page<WorkoutSession> page = new PageImpl<>(List.of(deleted));
        when(sessionRepository.findByUserIdAndUpdatedAtGreaterThanEqual(eq(USER_ID), eq(since), any()))
                .thenReturn(page);

        Page<WorkoutSessionResponse> result = service.findDelta(since, requested);

        assertThat(result.getContent()).singleElement().satisfies(r -> {
            assertThat(r.id()).isEqualTo(2L);
            assertThat(r.deletedAt()).isEqualTo(deleted.getDeletedAt());
        });
    }

    private static Exercise exercise(Long id, String name) {
        Exercise e = new Exercise();
        e.setId(id);
        e.setName(name);
        return e;
    }

    private static WorkoutTemplate template(Long id, String name) {
        WorkoutTemplate t = new WorkoutTemplate();
        t.setId(id);
        t.setName(name);
        return t;
    }
}

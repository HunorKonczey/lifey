package com.lifey.workout.template.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.domain.BaseEntity;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.workout.exercise.Exercise;
import com.lifey.workout.exercise.ExerciseRepository;
import com.lifey.workout.template.WorkoutTemplate;
import com.lifey.workout.template.WorkoutTemplateExercise;
import com.lifey.workout.template.WorkoutTemplateRepository;
import com.lifey.workout.template.WorkoutTemplateUpdatedEvent;
import com.lifey.workout.template.dto.TemplateExerciseEntry;
import com.lifey.workout.template.dto.WorkoutTemplateRequest;
import com.lifey.workout.template.dto.WorkoutTemplateResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;
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
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class WorkoutTemplateServiceImplTest {

    private static final Long USER_ID = 1L;

    @Mock
    WorkoutTemplateRepository templateRepository;

    @Mock
    ExerciseRepository exerciseRepository;

    @Mock
    UserRepository userRepository;

    @Mock
    CurrentUserProvider currentUserProvider;

    @Mock
    ApplicationEventPublisher eventPublisher;

    @InjectMocks
    WorkoutTemplateServiceImpl service;

    @BeforeEach
    void stubCurrentUser() {
        lenient().when(currentUserProvider.getUserId()).thenReturn(USER_ID);
        lenient().when(userRepository.getReferenceById(USER_ID)).thenReturn(new User());
    }

    @Test
    void create_resolvesExercisesAndReturnsResponse() {
        when(exerciseRepository.findByIdAndUserId(1L, USER_ID)).thenReturn(Optional.of(exercise(1L, "Bench Press")));
        when(exerciseRepository.findByIdAndUserId(4L, USER_ID)).thenReturn(Optional.of(exercise(4L, "Overhead Press")));
        when(templateRepository.save(any(WorkoutTemplate.class))).thenAnswer(inv -> withId(inv.getArgument(0), 9L));
        WorkoutTemplateRequest request = new WorkoutTemplateRequest("Push day",
                List.of(new TemplateExerciseEntry(1L, 3), new TemplateExerciseEntry(4L, null)));

        WorkoutTemplateResponse result = service.create(request);

        assertThat(result.id()).isEqualTo(9L);
        assertThat(result.name()).isEqualTo("Push day");
        assertThat(result.exercises()).hasSize(2);
        assertThat(result.exercises().get(0).exerciseId()).isEqualTo(1L);
        assertThat(result.exercises().get(0).targetSets()).isEqualTo(3);
        assertThat(result.exercises().get(1).exerciseId()).isEqualTo(4L);
        assertThat(result.exercises().get(1).targetSets()).isNull();
    }

    @Test
    void create_throwsWhenExerciseMissing() {
        when(exerciseRepository.findByIdAndUserId(99L, USER_ID)).thenReturn(Optional.empty());
        WorkoutTemplateRequest request = new WorkoutTemplateRequest("Bad",
                List.of(new TemplateExerciseEntry(99L, null)));

        assertThatThrownBy(() -> service.create(request))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessageContaining("Exercise not found: 99");
    }

    @Test
    void update_replacesNameAndExercises() {
        WorkoutTemplate existing = new WorkoutTemplate();
        existing.setId(9L);
        existing.setName("Push day");
        WorkoutTemplateExercise oldLink = new WorkoutTemplateExercise();
        oldLink.setExercise(exercise(1L, "Bench Press"));
        existing.getExercises().add(oldLink);
        when(templateRepository.findByIdAndUserId(9L, USER_ID)).thenReturn(Optional.of(existing));
        when(exerciseRepository.findByIdAndUserId(4L, USER_ID)).thenReturn(Optional.of(exercise(4L, "Overhead Press")));

        WorkoutTemplateResponse result = service.update(9L, new WorkoutTemplateRequest("Shoulders",
                List.of(new TemplateExerciseEntry(4L, 4))));

        assertThat(result.id()).isEqualTo(9L);
        assertThat(result.name()).isEqualTo("Shoulders");
        assertThat(result.exercises()).singleElement().satisfies(e -> {
            assertThat(e.exerciseId()).isEqualTo(4L);
            assertThat(e.targetSets()).isEqualTo(4);
        });
    }

    // ---- duration and repetitions (LIF-106) ----

    private WorkoutTemplate storedTemplate(Integer durationMinutes, Integer benchReps) {
        WorkoutTemplate existing = new WorkoutTemplate();
        existing.setId(9L);
        existing.setName("Push day");
        existing.setDurationMinutes(durationMinutes);
        WorkoutTemplateExercise link = new WorkoutTemplateExercise();
        link.setExercise(exercise(1L, "Bench Press"));
        link.setTargetSets(3);
        link.setTargetReps(benchReps);
        existing.getExercises().add(link);
        when(templateRepository.findByIdAndUserId(9L, USER_ID)).thenReturn(Optional.of(existing));
        when(exerciseRepository.findByIdAndUserId(1L, USER_ID)).thenReturn(Optional.of(exercise(1L, "Bench Press")));
        return existing;
    }

    @Test
    void create_storesTheStatedDurationAndRepetitions_andZeroMeansNotSaid() {
        when(exerciseRepository.findByIdAndUserId(1L, USER_ID)).thenReturn(Optional.of(exercise(1L, "Bench Press")));
        when(exerciseRepository.findByIdAndUserId(4L, USER_ID)).thenReturn(Optional.of(exercise(4L, "Overhead Press")));
        when(templateRepository.save(any(WorkoutTemplate.class))).thenAnswer(inv -> withId(inv.getArgument(0), 9L));

        WorkoutTemplateResponse result = service.create(new WorkoutTemplateRequest("Push day",
                List.of(new TemplateExerciseEntry(1L, 3, 10), new TemplateExerciseEntry(4L, 3, 0)), 45));

        assertThat(result.durationMinutes()).isEqualTo(45);
        assertThat(result.exercises().get(0).targetReps()).isEqualTo(10);
        assertThat(result.exercises().get(1).targetReps()).isNull();
    }

    @Test
    void update_fromThePhone_keepsTheDurationAndRepetitionsTheTrainerSetOnTheWeb() {
        WorkoutTemplate existing = storedTemplate(50, 8);

        // What the phone sends: no duration, no repetitions - it does not know them.
        WorkoutTemplateResponse result = service.update(9L, new WorkoutTemplateRequest("Push day renamed",
                List.of(new TemplateExerciseEntry(1L, 4))));

        assertThat(existing.getDurationMinutes()).isEqualTo(50);
        assertThat(result.durationMinutes()).isEqualTo(50);
        assertThat(result.exercises()).singleElement().satisfies(e -> {
            assertThat(e.targetSets()).isEqualTo(4);
            assertThat(e.targetReps()).isEqualTo(8);
        });
    }

    @Test
    void update_aValueReplacesTheStoredOne_andZeroClearsIt() {
        WorkoutTemplate existing = storedTemplate(50, 8);

        service.update(9L, new WorkoutTemplateRequest("Push day", List.of(new TemplateExerciseEntry(1L, 3, 12)), 40));
        assertThat(existing.getDurationMinutes()).isEqualTo(40);
        assertThat(existing.getExercises().getFirst().getTargetReps()).isEqualTo(12);

        service.update(9L, new WorkoutTemplateRequest("Push day", List.of(new TemplateExerciseEntry(1L, 3, 0)), 0));
        assertThat(existing.getDurationMinutes()).isNull();
        assertThat(existing.getExercises().getFirst().getTargetReps()).isNull();
    }

    @Test
    void update_anExerciseAddedOnThePhoneStartsWithoutRepetitions_theOthersKeepTheirs() {
        WorkoutTemplate existing = storedTemplate(null, 8);
        when(exerciseRepository.findByIdAndUserId(4L, USER_ID)).thenReturn(Optional.of(exercise(4L, "Overhead Press")));

        WorkoutTemplateResponse result = service.update(9L, new WorkoutTemplateRequest("Push day",
                List.of(new TemplateExerciseEntry(4L, 3), new TemplateExerciseEntry(1L, 3))));

        assertThat(result.exercises()).extracting(TemplateExerciseEntry::exerciseId, TemplateExerciseEntry::targetReps)
                .containsExactly(org.assertj.core.groups.Tuple.tuple(4L, null), org.assertj.core.groups.Tuple.tuple(1L, 8));
        assertThat(existing.getDurationMinutes()).isNull();
    }

    @Test
    void update_publishesUpdatedEventForLiveSync() {
        WorkoutTemplate existing = new WorkoutTemplate();
        existing.setId(9L);
        existing.setName("Push day");
        when(templateRepository.findByIdAndUserId(9L, USER_ID)).thenReturn(Optional.of(existing));
        when(exerciseRepository.findByIdAndUserId(1L, USER_ID)).thenReturn(Optional.of(exercise(1L, "Bench Press")));

        service.update(9L, new WorkoutTemplateRequest("Push day", List.of(new TemplateExerciseEntry(1L, 3))));

        ArgumentCaptor<WorkoutTemplateUpdatedEvent> captor = ArgumentCaptor.forClass(WorkoutTemplateUpdatedEvent.class);
        verify(eventPublisher).publishEvent(captor.capture());
        assertThat(captor.getValue().trainerId()).isEqualTo(USER_ID);
        assertThat(captor.getValue().templateId()).isEqualTo(9L);
    }

    @Test
    void update_throwsWhenTemplateMissing() {
        when(templateRepository.findByIdAndUserId(99L, USER_ID)).thenReturn(Optional.empty());
        WorkoutTemplateRequest request = new WorkoutTemplateRequest("X", List.of(new TemplateExerciseEntry(1L, null)));

        assertThatThrownBy(() -> service.update(99L, request))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessageContaining("Workout template not found: 99");
    }

    @Test
    void delete_throwsWhenMissing() {
        when(templateRepository.findByIdAndUserId(99L, USER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.delete(99L))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessageContaining("Workout template not found: 99");
    }

    @Test
    void delete_setsDeletedAtInsteadOfRemovingRow() {
        WorkoutTemplate existing = new WorkoutTemplate();
        existing.setId(9L);
        when(templateRepository.findByIdAndUserId(9L, USER_ID)).thenReturn(Optional.of(existing));

        service.delete(9L);

        assertThat(existing.getDeletedAt()).isNotNull();
    }

    @Test
    void update_exerciseLinkOnlyEditBumpsParentUpdatedAt() {
        WorkoutTemplate existing = new WorkoutTemplate();
        existing.setId(9L);
        existing.setName("Push day");
        existing.setUpdatedAt(Instant.parse("2026-06-18T08:00:00Z"));
        when(templateRepository.findByIdAndUserId(9L, USER_ID)).thenReturn(Optional.of(existing));
        when(exerciseRepository.findByIdAndUserId(1L, USER_ID)).thenReturn(Optional.of(exercise(1L, "Bench Press")));

        // Same name as before — only the exercise link's target sets differ.
        service.update(9L, new WorkoutTemplateRequest("Push day",
                List.of(new TemplateExerciseEntry(1L, 5))));

        assertThat(existing.getUpdatedAt()).isAfter(Instant.parse("2026-06-18T08:00:00Z"));
    }

    @Test
    void findDelta_isUserScopedAndIncludesTombstones() {
        WorkoutTemplate deleted = new WorkoutTemplate();
        deleted.setId(2L);
        deleted.setDeletedAt(Instant.parse("2026-06-19T00:00:00Z"));

        Instant since = Instant.parse("2026-06-17T00:00:00Z");
        Pageable requested = PageRequest.of(0, 50);
        Page<WorkoutTemplate> page = new PageImpl<>(List.of(deleted));
        when(templateRepository.findByUserIdAndUpdatedAtGreaterThanEqual(eq(USER_ID), eq(since), any()))
                .thenReturn(page);

        Page<WorkoutTemplateResponse> result = service.findDelta(since, requested);

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

    private static <T extends BaseEntity> T withId(T entity, Long id) {
        entity.setId(id);
        return entity;
    }
}

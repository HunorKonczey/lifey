package com.lifey.workout.exercise.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.domain.BaseEntity;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.workout.exercise.Equipment;
import com.lifey.workout.exercise.Exercise;
import com.lifey.workout.exercise.ExerciseRepository;
import com.lifey.workout.exercise.MuscleGroup;
import com.lifey.workout.exercise.dto.ExerciseRequest;
import com.lifey.workout.exercise.dto.ExerciseResponse;
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
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ExerciseServiceImplTest {

    private static final Long USER_ID = 42L;

    @Mock
    ExerciseRepository repository;

    @Mock
    UserRepository userRepository;

    @Mock
    CurrentUserProvider currentUserProvider;

    @InjectMocks
    ExerciseServiceImpl service;

    @BeforeEach
    void setUp() {
        when(currentUserProvider.getUserId()).thenReturn(USER_ID);
    }

    @Test
    void findAll_mapsExercises() {
        when(repository.findAllByUserIdAndDeletedAtIsNullOrderByNameAsc(USER_ID))
                .thenReturn(List.of(exercise(1L, "Squat")));

        List<ExerciseResponse> result = service.findAll();

        assertThat(result).singleElement().satisfies(r -> {
            assertThat(r.id()).isEqualTo(1L);
            assertThat(r.name()).isEqualTo("Squat");
            assertThat(r.category()).isNull();
            assertThat(r.equipment()).isNull();
        });
    }

    @Test
    void findAll_mapsCategoryAndEquipment() {
        Exercise e = exercise(2L, "Bench Press");
        e.setCategory(MuscleGroup.CHEST);
        e.setEquipment(Equipment.BARBELL);
        when(repository.findAllByUserIdAndDeletedAtIsNullOrderByNameAsc(USER_ID)).thenReturn(List.of(e));

        List<ExerciseResponse> result = service.findAll();

        assertThat(result).singleElement().satisfies(r -> {
            assertThat(r.category()).isEqualTo("CHEST");
            assertThat(r.equipment()).isEqualTo("BARBELL");
        });
    }

    @Test
    void findById_throwsWhenMissing() {
        when(repository.findByIdAndUserId(99L, USER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.findById(99L))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void create_savesAndReturnsResponse() {
        when(userRepository.getReferenceById(USER_ID)).thenReturn(new User());
        when(repository.save(any(Exercise.class))).thenAnswer(inv -> withId(inv.getArgument(0), 5L));

        ExerciseResponse result = service.create(new ExerciseRequest("Lunge", MuscleGroup.QUADS, Equipment.BODYWEIGHT, null, null));

        assertThat(result.id()).isEqualTo(5L);
        assertThat(result.name()).isEqualTo("Lunge");
        assertThat(result.category()).isEqualTo("QUADS");
        assertThat(result.equipment()).isEqualTo("BODYWEIGHT");
    }

    @Test
    void create_nullCategoryAndEquipmentSavesOk() {
        when(userRepository.getReferenceById(USER_ID)).thenReturn(new User());
        when(repository.save(any(Exercise.class))).thenAnswer(inv -> withId(inv.getArgument(0), 6L));

        ExerciseResponse result = service.create(new ExerciseRequest("Plank", null, null, null, null));

        assertThat(result.category()).isNull();
        assertThat(result.equipment()).isNull();
    }

    @Test
    void update_appliesChangesToExisting() {
        Exercise existing = exercise(3L, "Old");
        when(repository.findByIdAndUserId(3L, USER_ID)).thenReturn(Optional.of(existing));

        ExerciseResponse result = service.update(3L, new ExerciseRequest("New", MuscleGroup.BACK, Equipment.BARBELL, null, null));

        assertThat(result.name()).isEqualTo("New");
        assertThat(existing.getName()).isEqualTo("New");
        assertThat(existing.getCategory()).isEqualTo(MuscleGroup.BACK);
        assertThat(existing.getEquipment()).isEqualTo(Equipment.BARBELL);
    }

    @Test
    void create_withDefaultRestSecondsSavesAndReturnsIt() {
        when(userRepository.getReferenceById(USER_ID)).thenReturn(new User());
        when(repository.save(any(Exercise.class))).thenAnswer(inv -> withId(inv.getArgument(0), 7L));

        ExerciseResponse result = service.create(new ExerciseRequest("Deadlift", null, null, null, 120));

        assertThat(result.defaultRestSeconds()).isEqualTo(120);
    }

    @Test
    void update_nullDefaultRestSecondsClearsExistingOverride() {
        Exercise existing = exercise(3L, "Old");
        existing.setDefaultRestSeconds(120);
        when(repository.findByIdAndUserId(3L, USER_ID)).thenReturn(Optional.of(existing));

        ExerciseResponse result = service.update(3L, new ExerciseRequest("New", null, null, null, null));

        assertThat(result.defaultRestSeconds()).isNull();
        assertThat(existing.getDefaultRestSeconds()).isNull();
    }

    @Test
    void delete_throwsWhenMissing() {
        when(repository.findByIdAndUserId(99L, USER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.delete(99L))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void delete_setsDeletedAtInsteadOfRemovingRow() {
        Exercise existing = exercise(1L, "Squat");
        when(repository.findByIdAndUserId(1L, USER_ID)).thenReturn(Optional.of(existing));

        service.delete(1L);

        assertThat(existing.getDeletedAt()).isNotNull();
    }

    @Test
    void findDelta_includesTombstonesForUser() {
        Exercise deleted = exercise(2L, "Deleted exercise");
        deleted.setDeletedAt(Instant.parse("2026-06-19T00:00:00Z"));

        Instant since = Instant.parse("2026-06-17T00:00:00Z");
        Pageable requested = PageRequest.of(0, 50);
        Page<Exercise> page = new PageImpl<>(List.of(deleted));
        when(repository.findByUserIdAndUpdatedAtGreaterThanEqual(eq(USER_ID), eq(since), any())).thenReturn(page);

        Page<ExerciseResponse> result = service.findDelta(since, requested);

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

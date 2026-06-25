package com.lifey.workout.exercise;

import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.workout.exercise.dto.ExerciseRequest;
import com.lifey.workout.exercise.dto.ExerciseResponse;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ExerciseServiceImplTest {

    @Mock
    ExerciseRepository repository;

    @InjectMocks
    ExerciseServiceImpl service;

    @Test
    void findAll_mapsExercises() {
        when(repository.findAllByOrderByNameAsc()).thenReturn(List.of(exercise(1L, "Squat")));

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
        when(repository.findAllByOrderByNameAsc()).thenReturn(List.of(e));

        List<ExerciseResponse> result = service.findAll();

        assertThat(result).singleElement().satisfies(r -> {
            assertThat(r.category()).isEqualTo("CHEST");
            assertThat(r.equipment()).isEqualTo("BARBELL");
        });
    }

    @Test
    void findById_throwsWhenMissing() {
        when(repository.findById(99L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.findById(99L))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void create_savesAndReturnsResponse() {
        when(repository.save(any(Exercise.class))).thenAnswer(inv -> {
            Exercise e = inv.getArgument(0);
            e.setId(5L);
            return e;
        });

        ExerciseResponse result = service.create(new ExerciseRequest("Lunge", MuscleGroup.QUADS, Equipment.BODYWEIGHT));

        assertThat(result.id()).isEqualTo(5L);
        assertThat(result.name()).isEqualTo("Lunge");
        assertThat(result.category()).isEqualTo("QUADS");
        assertThat(result.equipment()).isEqualTo("BODYWEIGHT");
    }

    @Test
    void create_nullCategoryAndEquipmentSavesOk() {
        when(repository.save(any(Exercise.class))).thenAnswer(inv -> {
            Exercise e = inv.getArgument(0);
            e.setId(6L);
            return e;
        });

        ExerciseResponse result = service.create(new ExerciseRequest("Plank", null, null));

        assertThat(result.category()).isNull();
        assertThat(result.equipment()).isNull();
    }

    @Test
    void update_appliesChangesToExisting() {
        Exercise existing = exercise(3L, "Old");
        when(repository.findById(3L)).thenReturn(Optional.of(existing));

        ExerciseResponse result = service.update(3L, new ExerciseRequest("New", MuscleGroup.BACK, Equipment.BARBELL));

        assertThat(result.name()).isEqualTo("New");
        assertThat(existing.getName()).isEqualTo("New");
        assertThat(existing.getCategory()).isEqualTo(MuscleGroup.BACK);
        assertThat(existing.getEquipment()).isEqualTo(Equipment.BARBELL);
    }

    @Test
    void delete_throwsWhenMissing() {
        when(repository.existsById(99L)).thenReturn(false);

        assertThatThrownBy(() -> service.delete(99L))
                .isInstanceOf(ResourceNotFoundException.class);
        verify(repository, never()).deleteById(any());
    }

    @Test
    void delete_removesWhenExists() {
        when(repository.existsById(1L)).thenReturn(true);

        service.delete(1L);

        verify(repository).deleteById(1L);
    }

    private static Exercise exercise(Long id, String name) {
        Exercise e = new Exercise();
        e.setId(id);
        e.setName(name);
        return e;
    }
}

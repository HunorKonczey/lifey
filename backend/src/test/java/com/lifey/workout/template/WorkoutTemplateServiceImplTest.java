package com.lifey.workout.template;

import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.workout.exercise.Exercise;
import com.lifey.workout.exercise.ExerciseRepository;
import com.lifey.workout.template.dto.WorkoutTemplateRequest;
import com.lifey.workout.template.dto.WorkoutTemplateResponse;
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
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class WorkoutTemplateServiceImplTest {

    @Mock
    WorkoutTemplateRepository templateRepository;

    @Mock
    ExerciseRepository exerciseRepository;

    @InjectMocks
    WorkoutTemplateServiceImpl service;

    @Test
    void create_resolvesExercisesAndReturnsResponse() {
        when(exerciseRepository.findById(1L)).thenReturn(Optional.of(exercise(1L, "Bench Press")));
        when(exerciseRepository.findById(4L)).thenReturn(Optional.of(exercise(4L, "Overhead Press")));
        when(templateRepository.save(any(WorkoutTemplate.class))).thenAnswer(inv -> {
            WorkoutTemplate t = inv.getArgument(0);
            t.setId(9L);
            return t;
        });
        WorkoutTemplateRequest request = new WorkoutTemplateRequest("Push day", List.of(1L, 4L));

        WorkoutTemplateResponse result = service.create(request);

        assertThat(result.id()).isEqualTo(9L);
        assertThat(result.name()).isEqualTo("Push day");
        assertThat(result.exerciseIds()).containsExactly(1L, 4L);
    }

    @Test
    void create_throwsWhenExerciseMissing() {
        when(exerciseRepository.findById(99L)).thenReturn(Optional.empty());
        WorkoutTemplateRequest request = new WorkoutTemplateRequest("Bad", List.of(99L));

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

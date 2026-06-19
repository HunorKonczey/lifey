package com.lifey.workout.template;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.workout.exercise.Exercise;
import com.lifey.workout.exercise.ExerciseRepository;
import com.lifey.workout.template.dto.WorkoutTemplateRequest;
import com.lifey.workout.template.dto.WorkoutTemplateResponse;
import org.junit.jupiter.api.BeforeEach;
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
import static org.mockito.Mockito.lenient;
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

    @InjectMocks
    WorkoutTemplateServiceImpl service;

    @BeforeEach
    void stubCurrentUser() {
        lenient().when(currentUserProvider.getUserId()).thenReturn(USER_ID);
        lenient().when(userRepository.getReferenceById(USER_ID)).thenReturn(new User());
    }

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

    @Test
    void update_replacesNameAndExercises() {
        WorkoutTemplate existing = new WorkoutTemplate();
        existing.setId(9L);
        existing.setName("Push day");
        WorkoutTemplateExercise oldLink = new WorkoutTemplateExercise();
        oldLink.setExercise(exercise(1L, "Bench Press"));
        existing.getExercises().add(oldLink);
        when(templateRepository.findByIdAndUserId(9L, USER_ID)).thenReturn(Optional.of(existing));
        when(exerciseRepository.findById(4L)).thenReturn(Optional.of(exercise(4L, "Overhead Press")));

        WorkoutTemplateResponse result =
                service.update(9L, new WorkoutTemplateRequest("Shoulders", List.of(4L)));

        assertThat(result.id()).isEqualTo(9L);
        assertThat(result.name()).isEqualTo("Shoulders");
        assertThat(result.exerciseIds()).containsExactly(4L);
    }

    @Test
    void update_throwsWhenTemplateMissing() {
        when(templateRepository.findByIdAndUserId(99L, USER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.update(99L, new WorkoutTemplateRequest("X", List.of(1L))))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessageContaining("Workout template not found: 99");
    }

    @Test
    void delete_throwsWhenMissing() {
        when(templateRepository.existsByIdAndUserId(99L, USER_ID)).thenReturn(false);

        assertThatThrownBy(() -> service.delete(99L))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessageContaining("Workout template not found: 99");
    }

    private static Exercise exercise(Long id, String name) {
        Exercise e = new Exercise();
        e.setId(id);
        e.setName(name);
        return e;
    }
}

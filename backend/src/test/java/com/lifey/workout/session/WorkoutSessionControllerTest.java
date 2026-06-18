package com.lifey.workout.session;

import com.lifey.workout.session.dto.ExerciseSetResponse;
import com.lifey.workout.session.dto.WorkoutSessionResponse;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(WorkoutSessionController.class)
class WorkoutSessionControllerTest {

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    WorkoutSessionService workoutSessionService;

    @Test
    void create_returnsCreatedWithSets() throws Exception {
        when(workoutSessionService.create(any())).thenReturn(new WorkoutSessionResponse(2L,
                Instant.parse("2026-06-01T05:00:00Z"), null,
                List.of(new ExerciseSetResponse(1L, "Bench Press", 10, 60.0))));

        mockMvc.perform(post("/api/v1/workout-sessions").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"startedAt\":\"2026-06-01T05:00:00Z\","
                                + "\"sets\":[{\"exerciseId\":1,\"reps\":10,\"weight\":60}]}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(2))
                .andExpect(jsonPath("$.finishedAt").doesNotExist())
                .andExpect(jsonPath("$.sets[0].exerciseName").value("Bench Press"));
    }

    @Test
    void create_zeroRepsOrNegativeWeightReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/workout-sessions").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"startedAt\":\"2026-06-01T05:00:00Z\","
                                + "\"sets\":[{\"exerciseId\":1,\"reps\":0,\"weight\":-5}]}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400));

        verify(workoutSessionService, never()).create(any());
    }

    @Test
    void create_emptySetsReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/workout-sessions").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"startedAt\":\"2026-06-01T05:00:00Z\",\"sets\":[]}"))
                .andExpect(status().isBadRequest());

        verify(workoutSessionService, never()).create(any());
    }
}

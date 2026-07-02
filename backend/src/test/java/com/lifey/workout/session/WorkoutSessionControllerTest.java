package com.lifey.workout.session;

import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.workout.session.dto.ExerciseSetResponse;
import com.lifey.workout.session.dto.ExerciseSummary;
import com.lifey.workout.session.dto.WorkoutSessionResponse;
import com.lifey.workout.session.service.WorkoutSessionService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.data.domain.PageImpl;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(WorkoutSessionController.class)
class WorkoutSessionControllerTest {

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    WorkoutSessionService workoutSessionService;

    @Test
    void create_returnsCreatedWithPlannedExercisesAndSets() throws Exception {
        when(workoutSessionService.create(any())).thenReturn(new WorkoutSessionResponse(2L,
                Instant.parse("2026-06-01T05:00:00Z"), null,
                List.of(new ExerciseSummary(1L, "Bench Press")),
                List.of(new ExerciseSetResponse(1L, "Bench Press", 10, 60.0,
                        Instant.parse("2026-06-01T05:05:00Z"))),
                null, null, null, null, null, Instant.parse("2026-06-01T05:00:00Z"), null));

        mockMvc.perform(post("/api/v1/workout-sessions").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"startedAt\":\"2026-06-01T05:00:00Z\","
                                + "\"exerciseIds\":[1],"
                                + "\"sets\":[{\"exerciseId\":1,\"reps\":10,\"weight\":60,"
                                + "\"performedAt\":\"2026-06-01T05:05:00Z\"}]}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(2))
                .andExpect(jsonPath("$.finishedAt").doesNotExist())
                .andExpect(jsonPath("$.exercises[0].exerciseName").value("Bench Press"))
                .andExpect(jsonPath("$.sets[0].exerciseName").value("Bench Press"))
                .andExpect(jsonPath("$.activeCalories").doesNotExist())
                .andExpect(jsonPath("$.healthWorkoutId").doesNotExist());
    }

    @Test
    void create_withHealthFieldsRoundTrips() throws Exception {
        when(workoutSessionService.create(any())).thenReturn(new WorkoutSessionResponse(2L,
                Instant.parse("2026-06-01T05:00:00Z"), Instant.parse("2026-06-01T06:00:00Z"),
                List.of(new ExerciseSummary(1L, "Bench Press")),
                List.of(new ExerciseSetResponse(1L, "Bench Press", 10, 60.0,
                        Instant.parse("2026-06-01T05:05:00Z"))),
                450.0, 132.0, "HK-UUID-1", null, null, Instant.parse("2026-06-01T05:00:00Z"), null));

        mockMvc.perform(post("/api/v1/workout-sessions").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"startedAt\":\"2026-06-01T05:00:00Z\","
                                + "\"finishedAt\":\"2026-06-01T06:00:00Z\","
                                + "\"exerciseIds\":[1],"
                                + "\"sets\":[{\"exerciseId\":1,\"reps\":10,\"weight\":60,"
                                + "\"performedAt\":\"2026-06-01T05:05:00Z\"}],"
                                + "\"activeCalories\":450,\"averageHeartRate\":132,"
                                + "\"healthWorkoutId\":\"HK-UUID-1\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.activeCalories").value(450.0))
                .andExpect(jsonPath("$.averageHeartRate").value(132.0))
                .andExpect(jsonPath("$.healthWorkoutId").value("HK-UUID-1"));
    }

    @Test
    void create_emptyExercisesAndSetsReturnsCreated() throws Exception {
        when(workoutSessionService.create(any())).thenReturn(new WorkoutSessionResponse(5L,
                Instant.parse("2026-06-01T05:00:00Z"), null, List.of(), List.of(),
                null, null, null, null, null, Instant.parse("2026-06-01T05:00:00Z"), null));

        mockMvc.perform(post("/api/v1/workout-sessions").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"startedAt\":\"2026-06-01T05:00:00Z\","
                                + "\"exerciseIds\":[],\"sets\":[]}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.exercises").isEmpty())
                .andExpect(jsonPath("$.sets").isEmpty());
    }

    @Test
    void create_missingExerciseIdsReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/workout-sessions").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"startedAt\":\"2026-06-01T05:00:00Z\",\"sets\":[]}"))
                .andExpect(status().isBadRequest());

        verify(workoutSessionService, never()).create(any());
    }

    @Test
    void create_zeroRepsOrNegativeWeightReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/workout-sessions").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"startedAt\":\"2026-06-01T05:00:00Z\",\"exerciseIds\":[],"
                                + "\"sets\":[{\"exerciseId\":1,\"reps\":0,\"weight\":-5,"
                                + "\"performedAt\":\"2026-06-01T05:05:00Z\"}]}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400));

        verify(workoutSessionService, never()).create(any());
    }

    @Test
    void update_returnsOk() throws Exception {
        when(workoutSessionService.update(eq(2L), any())).thenReturn(new WorkoutSessionResponse(2L,
                Instant.parse("2026-06-01T05:00:00Z"),
                Instant.parse("2026-06-01T06:00:00Z"),
                List.of(new ExerciseSummary(1L, "Bench Press")),
                List.of(new ExerciseSetResponse(1L, "Bench Press", 8, 70.0,
                        Instant.parse("2026-06-01T05:35:00Z"))),
                null, null, null, null, null, Instant.parse("2026-06-01T05:00:00Z"), null));

        mockMvc.perform(put("/api/v1/workout-sessions/2").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"startedAt\":\"2026-06-01T05:00:00Z\","
                                + "\"finishedAt\":\"2026-06-01T06:00:00Z\","
                                + "\"exerciseIds\":[1],"
                                + "\"sets\":[{\"exerciseId\":1,\"reps\":8,\"weight\":70,"
                                + "\"performedAt\":\"2026-06-01T05:35:00Z\"}]}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.finishedAt").value("2026-06-01T06:00:00Z"))
                .andExpect(jsonPath("$.sets[0].reps").value(8));
    }

    @Test
    void delta_returnsPageIncludingTombstones() throws Exception {
        Instant since = Instant.parse("2026-06-17T00:00:00Z");
        WorkoutSessionResponse tombstoned = new WorkoutSessionResponse(2L,
                Instant.parse("2026-06-01T05:00:00Z"), null, List.of(), List.of(),
                null, null, null, null, null,
                Instant.parse("2026-06-19T00:00:00Z"), Instant.parse("2026-06-19T00:00:00Z"));
        when(workoutSessionService.findDelta(eq(since), any())).thenReturn(new PageImpl<>(List.of(tombstoned)));

        mockMvc.perform(get("/api/v1/workout-sessions").param("updatedSince", since.toString()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].id").value(2))
                .andExpect(jsonPath("$.content[0].deletedAt").exists());
    }

    @Test
    void delete_returnsNoContent() throws Exception {
        mockMvc.perform(delete("/api/v1/workout-sessions/2"))
                .andExpect(status().isNoContent());

        verify(workoutSessionService).delete(2L);
    }

    @Test
    void delete_notFoundReturns404() throws Exception {
        doThrow(new ResourceNotFoundException("Workout session not found: 99"))
                .when(workoutSessionService).delete(99L);

        mockMvc.perform(delete("/api/v1/workout-sessions/99"))
                .andExpect(status().isNotFound());
    }
}

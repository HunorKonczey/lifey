package com.lifey.workout.template;

import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.workout.template.dto.TemplateExerciseEntry;
import com.lifey.workout.template.dto.WorkoutTemplateResponse;
import com.lifey.workout.template.service.WorkoutTemplateService;
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

@WebMvcTest(WorkoutTemplateController.class)
class WorkoutTemplateControllerTest {

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    WorkoutTemplateService workoutTemplateService;

    @Test
    void create_returnsCreated() throws Exception {
        when(workoutTemplateService.create(any()))
                .thenReturn(new WorkoutTemplateResponse(9L, "Push day",
                        List.of(new TemplateExerciseEntry(1L, 3), new TemplateExerciseEntry(4L, null)),
                        Instant.parse("2026-06-18T08:00:00Z"), null, null));

        mockMvc.perform(post("/api/v1/workout-templates").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Push day\",\"exercises\":[{\"exerciseId\":1,\"targetSets\":3},{\"exerciseId\":4}]}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(9))
                .andExpect(jsonPath("$.exercises[0].exerciseId").value(1))
                .andExpect(jsonPath("$.exercises[0].targetSets").value(3))
                .andExpect(jsonPath("$.exercises[1].exerciseId").value(4));
    }

    @Test
    void create_emptyExercisesReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/workout-templates").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"\",\"exercises\":[]}"))
                .andExpect(status().isBadRequest());

        verify(workoutTemplateService, never()).create(any());
    }

    @Test
    void create_nullExerciseIdReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/workout-templates").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Bad\",\"exercises\":[{\"exerciseId\":null}]}"))
                .andExpect(status().isBadRequest());

        verify(workoutTemplateService, never()).create(any());
    }

    @Test
    void create_unknownExerciseReturns404() throws Exception {
        when(workoutTemplateService.create(any()))
                .thenThrow(new ResourceNotFoundException("Exercise not found: 99"));

        mockMvc.perform(post("/api/v1/workout-templates").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Bad\",\"exercises\":[{\"exerciseId\":99}]}"))
                .andExpect(status().isNotFound());
    }

    @Test
    void update_returnsOk() throws Exception {
        when(workoutTemplateService.update(eq(9L), any()))
                .thenReturn(new WorkoutTemplateResponse(9L, "Shoulders",
                        List.of(new TemplateExerciseEntry(4L, null)),
                        Instant.parse("2026-06-18T08:00:00Z"), null, null));

        mockMvc.perform(put("/api/v1/workout-templates/9").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Shoulders\",\"exercises\":[{\"exerciseId\":4}]}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("Shoulders"))
                .andExpect(jsonPath("$.exercises[0].exerciseId").value(4));
    }

    @Test
    void delta_returnsPageIncludingTombstones() throws Exception {
        Instant since = Instant.parse("2026-06-17T00:00:00Z");
        WorkoutTemplateResponse tombstoned = new WorkoutTemplateResponse(2L, "Deleted template", List.of(),
                Instant.parse("2026-06-19T00:00:00Z"), Instant.parse("2026-06-19T00:00:00Z"), null);
        when(workoutTemplateService.findDelta(eq(since), any())).thenReturn(new PageImpl<>(List.of(tombstoned)));

        mockMvc.perform(get("/api/v1/workout-templates").param("updatedSince", since.toString()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].id").value(2))
                .andExpect(jsonPath("$.content[0].deletedAt").exists());
    }

    @Test
    void delete_returnsNoContent() throws Exception {
        mockMvc.perform(delete("/api/v1/workout-templates/9"))
                .andExpect(status().isNoContent());

        verify(workoutTemplateService).delete(9L);
    }

    @Test
    void delete_notFoundReturns404() throws Exception {
        doThrow(new ResourceNotFoundException("Workout template not found: 99"))
                .when(workoutTemplateService).delete(99L);

        mockMvc.perform(delete("/api/v1/workout-templates/99"))
                .andExpect(status().isNotFound());
    }
}

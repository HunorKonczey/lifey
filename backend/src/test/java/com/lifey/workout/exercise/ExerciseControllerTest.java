package com.lifey.workout.exercise;

import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.workout.exercise.dto.ExerciseResponse;
import com.lifey.workout.exercise.service.ExerciseService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.dao.DataIntegrityViolationException;
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

@WebMvcTest(ExerciseController.class)
class ExerciseControllerTest {

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    ExerciseService exerciseService;

    @Test
    void list_returnsOk() throws Exception {
        when(exerciseService.findAll())
                .thenReturn(List.of(new ExerciseResponse(1L, "Bench Press", "CHEST", "BARBELL",
                        Instant.parse("2026-06-18T08:00:00Z"), null, null)));

        mockMvc.perform(get("/api/v1/exercises"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].name").value("Bench Press"))
                .andExpect(jsonPath("$[0].category").value("CHEST"))
                .andExpect(jsonPath("$[0].equipment").value("BARBELL"));
    }

    @Test
    void list_nullCategoryAndEquipmentReturnsOk() throws Exception {
        when(exerciseService.findAll())
                .thenReturn(List.of(new ExerciseResponse(2L, "Plank", null, null,
                        Instant.parse("2026-06-18T08:00:00Z"), null, null)));

        mockMvc.perform(get("/api/v1/exercises"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].category").doesNotExist())
                .andExpect(jsonPath("$[0].equipment").doesNotExist());
    }

    @Test
    void create_returnsCreated() throws Exception {
        when(exerciseService.create(any())).thenReturn(new ExerciseResponse(9L, "Lateral Raise", "SHOULDERS", null,
                Instant.parse("2026-06-18T08:00:00Z"), null, null));

        mockMvc.perform(post("/api/v1/exercises").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Lateral Raise\",\"category\":\"SHOULDERS\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(9))
                .andExpect(jsonPath("$.category").value("SHOULDERS"));
    }

    @Test
    void create_invalidCategoryReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/exercises").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"X\",\"category\":\"INVALID_CATEGORY\"}"))
                .andExpect(status().isBadRequest());

        verify(exerciseService, never()).create(any());
    }

    @Test
    void create_blankNameReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/exercises").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"\"}"))
                .andExpect(status().isBadRequest());

        verify(exerciseService, never()).create(any());
    }

    @Test
    void delta_returnsPageIncludingTombstones() throws Exception {
        Instant since = Instant.parse("2026-06-17T00:00:00Z");
        ExerciseResponse tombstoned = new ExerciseResponse(2L, "Deleted exercise", null, null,
                Instant.parse("2026-06-19T00:00:00Z"), Instant.parse("2026-06-19T00:00:00Z"), null);
        when(exerciseService.findDelta(eq(since), any())).thenReturn(new PageImpl<>(List.of(tombstoned)));

        mockMvc.perform(get("/api/v1/exercises").param("updatedSince", since.toString()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].id").value(2))
                .andExpect(jsonPath("$.content[0].deletedAt").exists());
    }

    @Test
    void delete_referencedReturnsConflict() throws Exception {
        doThrow(new DataIntegrityViolationException("fk_violation"))
                .when(exerciseService).delete(1L);

        mockMvc.perform(delete("/api/v1/exercises/1"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.status").value(409));
    }

    @Test
    void delete_notFoundReturns404() throws Exception {
        doThrow(new ResourceNotFoundException("Exercise not found: 99"))
                .when(exerciseService).delete(99L);

        mockMvc.perform(delete("/api/v1/exercises/99"))
                .andExpect(status().isNotFound());
    }
}

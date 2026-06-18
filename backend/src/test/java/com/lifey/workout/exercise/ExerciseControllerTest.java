package com.lifey.workout.exercise;

import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.workout.exercise.dto.ExerciseResponse;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
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
                .thenReturn(List.of(new ExerciseResponse(1L, "Bench Press")));

        mockMvc.perform(get("/api/v1/exercises"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].name").value("Bench Press"));
    }

    @Test
    void create_returnsCreated() throws Exception {
        when(exerciseService.create(any())).thenReturn(new ExerciseResponse(9L, "Lateral Raise"));

        mockMvc.perform(post("/api/v1/exercises").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Lateral Raise\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(9));
    }

    @Test
    void create_blankNameReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/exercises").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"\"}"))
                .andExpect(status().isBadRequest());

        verify(exerciseService, never()).create(any());
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

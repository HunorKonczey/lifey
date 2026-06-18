package com.lifey.workout.template;

import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.workout.template.dto.WorkoutTemplateResponse;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
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
                .thenReturn(new WorkoutTemplateResponse(9L, "Push day", List.of(1L, 4L)));

        mockMvc.perform(post("/api/v1/workout-templates").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Push day\",\"exerciseIds\":[1,4]}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(9))
                .andExpect(jsonPath("$.exerciseIds[1]").value(4));
    }

    @Test
    void create_emptyExerciseIdsReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/workout-templates").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"\",\"exerciseIds\":[]}"))
                .andExpect(status().isBadRequest());

        verify(workoutTemplateService, never()).create(any());
    }

    @Test
    void create_unknownExerciseReturns404() throws Exception {
        when(workoutTemplateService.create(any()))
                .thenThrow(new ResourceNotFoundException("Exercise not found: 99"));

        mockMvc.perform(post("/api/v1/workout-templates").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Bad\",\"exerciseIds\":[99]}"))
                .andExpect(status().isNotFound());
    }

    @Test
    void update_returnsOk() throws Exception {
        when(workoutTemplateService.update(eq(9L), any()))
                .thenReturn(new WorkoutTemplateResponse(9L, "Shoulders", List.of(4L)));

        mockMvc.perform(put("/api/v1/workout-templates/9").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Shoulders\",\"exerciseIds\":[4]}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("Shoulders"))
                .andExpect(jsonPath("$.exerciseIds[0]").value(4));
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

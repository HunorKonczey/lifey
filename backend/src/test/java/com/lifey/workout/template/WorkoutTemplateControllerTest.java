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
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
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
}

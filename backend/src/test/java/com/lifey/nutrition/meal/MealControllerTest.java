package com.lifey.nutrition.meal;

import com.lifey.nutrition.meal.dto.MealEntryResponse;
import com.lifey.nutrition.meal.dto.MealResponse;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.LocalDateTime;
import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(MealController.class)
class MealControllerTest {

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    MealService mealService;

    @Test
    void create_returnsCreated() throws Exception {
        when(mealService.create(any())).thenReturn(new MealResponse(4L,
                LocalDateTime.of(2026, 6, 1, 8, 0), MealType.BREAKFAST,
                List.of(new MealEntryResponse(1L, "Oats", 80.0, 311.2, 13.6))));

        mockMvc.perform(post("/api/v1/meals").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"dateTime\":\"2026-06-01T08:00:00\",\"mealType\":\"BREAKFAST\","
                                + "\"entries\":[{\"foodId\":1,\"quantityInGrams\":80}]}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.mealType").value("BREAKFAST"))
                .andExpect(jsonPath("$.entries[0].foodName").value("Oats"));
    }

    @Test
    void create_missingTypeOrEmptyEntriesReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/meals").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"dateTime\":\"2026-06-01T08:00:00\",\"mealType\":null,\"entries\":[]}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400));

        verify(mealService, never()).create(any());
    }

    @Test
    void create_unknownEnumReturns400FromUnreadableBody() throws Exception {
        mockMvc.perform(post("/api/v1/meals").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"dateTime\":\"2026-06-01T08:00:00\",\"mealType\":\"BRUNCH\","
                                + "\"entries\":[{\"foodId\":1,\"quantityInGrams\":80}]}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Malformed or unreadable request body"));

        verify(mealService, never()).create(any());
    }
}

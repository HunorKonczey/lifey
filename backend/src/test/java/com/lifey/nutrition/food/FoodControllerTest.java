package com.lifey.nutrition.food;

import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.nutrition.food.dto.FoodResponse;
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
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(FoodController.class)
class FoodControllerTest {

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    FoodService foodService;

    @Test
    void list_returnsOkWithJson() throws Exception {
        when(foodService.findAll())
                .thenReturn(List.of(new FoodResponse(1L, "Chicken", 165.0, 31.0, 0.0, 3.6)));

        mockMvc.perform(get("/api/v1/foods"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].name").value("Chicken"))
                .andExpect(jsonPath("$[0].caloriesPer100g").value(165.0));
    }

    @Test
    void create_returnsCreated() throws Exception {
        when(foodService.create(any()))
                .thenReturn(new FoodResponse(7L, "Rice", 130.0, 2.7, null, null));

        mockMvc.perform(post("/api/v1/foods").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Rice\",\"caloriesPer100g\":130,\"proteinPer100g\":2.7}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(7))
                .andExpect(jsonPath("$.name").value("Rice"));
    }

    @Test
    void create_invalidReturnsBadRequest() throws Exception {
        mockMvc.perform(post("/api/v1/foods").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"\",\"caloriesPer100g\":-1,\"proteinPer100g\":null}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.details").isArray());

        verify(foodService, never()).create(any());
    }

    @Test
    void getById_notFoundReturns404() throws Exception {
        when(foodService.findById(99L)).thenThrow(new ResourceNotFoundException("Food not found: 99"));

        mockMvc.perform(get("/api/v1/foods/99"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404))
                .andExpect(jsonPath("$.message").value("Food not found: 99"));
    }

    @Test
    void delete_returnsNoContent() throws Exception {
        mockMvc.perform(delete("/api/v1/foods/1"))
                .andExpect(status().isNoContent());

        verify(foodService).delete(1L);
    }
}

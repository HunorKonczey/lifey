package com.lifey.nutrition.recipe;

import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.nutrition.recipe.dto.RecipeIngredientResponse;
import com.lifey.nutrition.recipe.dto.RecipeRequest;
import com.lifey.nutrition.recipe.dto.RecipeResponse;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(RecipeController.class)
class RecipeControllerTest {

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    RecipeService recipeService;

    @Test
    void create_returnsCreatedWithIngredients() throws Exception {
        when(recipeService.create(any())).thenReturn(new RecipeResponse(7L, "Chicken & rice", "prep", true, 2,
                List.of(new RecipeIngredientResponse(1L, "Chicken", 200.0, 330.0, 62.0))));

        mockMvc.perform(post("/api/v1/recipes").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Chicken & rice\",\"description\":\"prep\",\"favorite\":true,"
                                + "\"ingredients\":[{\"foodId\":1,\"quantityInGrams\":200}]}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(7))
                .andExpect(jsonPath("$.favorite").value(true))
                .andExpect(jsonPath("$.ingredients[0].foodName").value("Chicken"));

        ArgumentCaptor<RecipeRequest> captor = ArgumentCaptor.forClass(RecipeRequest.class);
        verify(recipeService).create(captor.capture());
        assertThat(captor.getValue().favorite()).isTrue();
    }

    @Test
    void create_blankNameOrEmptyIngredientsReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/recipes").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"\",\"favorite\":false,\"ingredients\":[]}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400));

        verify(recipeService, never()).create(any());
    }

    @Test
    void create_unknownFoodReturns404() throws Exception {
        when(recipeService.create(any()))
                .thenThrow(new ResourceNotFoundException("Food not found: 99"));

        mockMvc.perform(post("/api/v1/recipes").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Bad\",\"favorite\":false,"
                                + "\"ingredients\":[{\"foodId\":99,\"quantityInGrams\":100}]}"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.message").value("Food not found: 99"));
    }
}

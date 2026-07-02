package com.lifey.nutrition.recipe;

import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.nutrition.recipe.dto.RecipeIngredientResponse;
import com.lifey.nutrition.recipe.dto.RecipeRequest;
import com.lifey.nutrition.recipe.dto.RecipeResponse;
import com.lifey.nutrition.recipe.service.RecipeService;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
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
                List.of(new RecipeIngredientResponse(1L, "Chicken", 200.0, 330.0, 62.0)),
                Instant.parse("2026-06-18T08:00:00Z"), null));

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
    void list_withNoParams_neverCallsPagedVariant() throws Exception {
        when(recipeService.findAll()).thenReturn(List.of());

        mockMvc.perform(get("/api/v1/recipes")).andExpect(status().isOk());

        verify(recipeService, never()).findPage(any(), any());
    }

    @Test
    void findPage_withSearch_passesSearchThrough() throws Exception {
        Pageable pageable = PageRequest.of(0, 200, org.springframework.data.domain.Sort.by("name", "id"));
        Page<RecipeResponse> page = new PageImpl<>(
                List.of(new RecipeResponse(2L, "Banana bread", null, false, 1, List.of(), Instant.now(), null)),
                pageable, 1);
        when(recipeService.findPage(eq(pageable), eq("banana"))).thenReturn(page);

        mockMvc.perform(get("/api/v1/recipes").param("page", "0").param("search", "banana"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].name").value("Banana bread"));
    }

    @Test
    void findPage_noSearch_passesNullThrough() throws Exception {
        Pageable pageable = PageRequest.of(0, 200, org.springframework.data.domain.Sort.by("name", "id"));
        Page<RecipeResponse> page = new PageImpl<>(
                List.of(new RecipeResponse(1L, "Apple pie", null, false, 1, List.of(), Instant.now(), null)),
                pageable, 1);
        when(recipeService.findPage(eq(pageable), isNull())).thenReturn(page);

        mockMvc.perform(get("/api/v1/recipes").param("page", "0"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].name").value("Apple pie"));
    }

    @Test
    void delta_returnsPageIncludingTombstones() throws Exception {
        Instant since = Instant.parse("2026-06-17T00:00:00Z");
        RecipeResponse tombstoned = new RecipeResponse(2L, "Deleted recipe", null, false, 1, List.of(),
                Instant.parse("2026-06-19T00:00:00Z"), Instant.parse("2026-06-19T00:00:00Z"));
        when(recipeService.findDelta(eq(since), any())).thenReturn(new PageImpl<>(List.of(tombstoned)));

        mockMvc.perform(get("/api/v1/recipes").param("updatedSince", since.toString()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].id").value(2))
                .andExpect(jsonPath("$.content[0].deletedAt").exists());
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

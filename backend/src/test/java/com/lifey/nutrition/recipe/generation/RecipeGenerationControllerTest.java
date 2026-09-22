package com.lifey.nutrition.recipe.generation;

import com.lifey.ai.exception.AiCreditsExhaustedException;
import com.lifey.ai.exception.AiUnavailableException;
import com.lifey.nutrition.recipe.generation.dto.GeneratedIngredientResponse;
import com.lifey.nutrition.recipe.generation.dto.GeneratedRecipeResponse;
import com.lifey.nutrition.recipe.generation.dto.MacroTotals;
import com.lifey.nutrition.recipe.generation.exception.InvalidGenerationRequestException;
import com.lifey.nutrition.recipe.generation.service.RecipeGenerationService;
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

@WebMvcTest(RecipeGenerationController.class)
class RecipeGenerationControllerTest {

    private static final String VALID = """
            {"dietType":"MEAT","mealType":"DINNER","calorieBand":"FROM_500_TO_700","meatType":"CHICKEN"}""";

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    RecipeGenerationService service;

    @Test
    void generate_returnsTheProposalWithBothIngredientShapes() throws Exception {
        when(service.generate(any())).thenReturn(new GeneratedRecipeResponse(
                "Chicken and rice", "1. Cook it.", 2,
                List.of(new GeneratedIngredientResponse(7L, null, "Chicken breast", 300),
                        new GeneratedIngredientResponse(null,
                                new GeneratedIngredientResponse.NewFood("Jasmine rice", 355, 7, 78, 0.6),
                                "Jasmine rice", 150)),
                new MacroTotals(530, 52, 59, 6)));

        mockMvc.perform(post("/api/v1/recipes/generate").contentType(MediaType.APPLICATION_JSON).content(VALID))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("Chicken and rice"))
                .andExpect(jsonPath("$.servings").value(2))
                .andExpect(jsonPath("$.ingredients[0].existingFoodId").value(7))
                .andExpect(jsonPath("$.ingredients[0].newFood").doesNotExist())
                .andExpect(jsonPath("$.ingredients[1].newFood.caloriesPer100g").value(355.0))
                .andExpect(jsonPath("$.perServing.calories").value(530.0));
    }

    @Test
    void generate_missingRequiredChoiceReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/recipes/generate").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"dietType":"MEAT","calorieBand":"UNDER_300"}"""))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.details").isNotEmpty());

        verify(service, never()).generate(any());
    }

    @Test
    void generate_unknownEnumValueReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/recipes/generate").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"dietType":"PALEO","mealType":"DINNER","calorieBand":"UNDER_300"}"""))
                .andExpect(status().isBadRequest());

        verify(service, never()).generate(any());
    }

    @Test
    void generate_contradictingWizardAnswersReturn400() throws Exception {
        when(service.generate(any()))
                .thenThrow(new InvalidGenerationRequestException("A meat type cannot be combined with VEGAN"));

        mockMvc.perform(post("/api/v1/recipes/generate").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"dietType":"VEGAN","mealType":"DINNER","calorieBand":"UNDER_300","meatType":"BEEF"}"""))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("A meat type cannot be combined with VEGAN"));
    }

    @Test
    void generate_creditsExhausted_returns402WithCode() throws Exception {
        when(service.generate(any())).thenThrow(new AiCreditsExhaustedException());

        mockMvc.perform(post("/api/v1/recipes/generate").contentType(MediaType.APPLICATION_JSON).content(VALID))
                .andExpect(status().isPaymentRequired())
                .andExpect(jsonPath("$.message").value("AI_CREDITS_EXHAUSTED"));
    }

    @Test
    void generate_modelFailure_returns502WithoutUpstreamDetail() throws Exception {
        when(service.generate(any())).thenThrow(new AiUnavailableException("Claude API rejected the request"));

        mockMvc.perform(post("/api/v1/recipes/generate").contentType(MediaType.APPLICATION_JSON).content(VALID))
                .andExpect(status().isBadGateway())
                .andExpect(jsonPath("$.message").value("AI_UNAVAILABLE"));
    }
}

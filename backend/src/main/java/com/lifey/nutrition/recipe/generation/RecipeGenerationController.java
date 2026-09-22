package com.lifey.nutrition.recipe.generation;

import com.lifey.nutrition.recipe.generation.dto.GeneratedRecipeResponse;
import com.lifey.nutrition.recipe.generation.dto.RecipeGenerationRequest;
import com.lifey.nutrition.recipe.generation.service.RecipeGenerationService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Recipe Generation", description = "AI recipe generation from a short wizard")
@RestController
@RequestMapping("/api/v1/recipes/generate")
@RequiredArgsConstructor
public class RecipeGenerationController {

    private final RecipeGenerationService service;

    @Operation(summary = "Generate a recipe proposal",
            description = "Designs a recipe from the wizard's constraints, reusing the caller's own "
                    + "foods by id wherever one fits. Nothing is stored: the client edits the "
                    + "proposal and saves it through the normal recipe endpoints. 400 when the diet "
                    + "type and meat type contradict each other, 402 AI_CREDITS_EXHAUSTED when this "
                    + "month's AI allowance is used up, 502 AI_UNAVAILABLE when the model call fails "
                    + "(no credit is used), 503 AI_NOT_CONFIGURED when the server has no API key.")
    @PostMapping
    public GeneratedRecipeResponse generate(@Valid @RequestBody RecipeGenerationRequest request) {
        return service.generate(request);
    }
}

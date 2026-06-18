package com.lifey.nutrition.recipe;

import com.lifey.nutrition.recipe.dto.RecipeRequest;
import com.lifey.nutrition.recipe.dto.RecipeResponse;

import java.util.List;

public interface RecipeService {

    List<RecipeResponse> findAll();

    RecipeResponse findById(Long id);

    RecipeResponse create(RecipeRequest request);

    RecipeResponse update(Long id, RecipeRequest request);

    void delete(Long id);
}

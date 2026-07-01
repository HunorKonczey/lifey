package com.lifey.nutrition.recipe;

import com.lifey.nutrition.recipe.dto.RecipeRequest;
import com.lifey.nutrition.recipe.dto.RecipeResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.time.Instant;
import java.util.List;

public interface RecipeService {

    List<RecipeResponse> findAll();

    Page<RecipeResponse> findPage(Pageable pageable, String search);

    Page<RecipeResponse> findDelta(Instant updatedSince, Pageable pageable);

    RecipeResponse findById(Long id);

    RecipeResponse create(RecipeRequest request);

    RecipeResponse update(Long id, RecipeRequest request);

    void delete(Long id);
}

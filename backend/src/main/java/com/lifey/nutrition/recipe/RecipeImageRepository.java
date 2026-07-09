package com.lifey.nutrition.recipe;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface RecipeImageRepository extends JpaRepository<RecipeImage, Long> {

    Optional<RecipeImage> findByRecipeId(Long recipeId);

    void deleteByRecipeId(Long recipeId);
}

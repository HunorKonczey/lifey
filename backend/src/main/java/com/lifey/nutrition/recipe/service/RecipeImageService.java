package com.lifey.nutrition.recipe.service;

import com.lifey.nutrition.recipe.RecipeImage;
import org.springframework.web.multipart.MultipartFile;

/**
 * Manages a recipe's photo. All methods scope the recipe lookup to the
 * current user (see docs/16-delta-sync-rollout.md ownership model) — no
 * separate authorization step is needed.
 */
public interface RecipeImageService {

    /**
     * @throws com.lifey.common.exception.ResourceNotFoundException if the recipe doesn't exist/isn't
     *                                                                owned by the current user, or has no photo set
     */
    RecipeImage find(Long recipeId);

    /**
     * Validates, re-encodes (resize + center-crop thumbnail + strip metadata) and
     * stores the given file as the recipe's photo, replacing any existing one.
     *
     * @throws com.lifey.common.exception.InvalidImageException if the file isn't a decodable JPEG/PNG
     */
    void upload(Long recipeId, MultipartFile file);

    void delete(Long recipeId);
}

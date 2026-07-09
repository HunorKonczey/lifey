package com.lifey.nutrition.recipe.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.common.image.ImageReencoder;
import com.lifey.nutrition.recipe.Recipe;
import com.lifey.nutrition.recipe.RecipeImage;
import com.lifey.nutrition.recipe.RecipeImageRepository;
import com.lifey.nutrition.recipe.RecipeRepository;
import com.lifey.nutrition.recipe.RecipeUpdatedEvent;
import lombok.RequiredArgsConstructor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.awt.image.BufferedImage;
import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.time.Instant;

@Service
@Transactional
@RequiredArgsConstructor
public class RecipeImageServiceImpl implements RecipeImageService {

    private static final int MAIN_MAX_SIDE = 1024;
    private static final int THUMBNAIL_SIZE = 256;

    private final RecipeImageRepository repository;
    private final RecipeRepository recipeRepository;
    private final CurrentUserProvider currentUserProvider;
    private final ApplicationEventPublisher eventPublisher;

    @Override
    @Transactional(readOnly = true)
    public RecipeImage find(Long recipeId) {
        getOwnedRecipe(recipeId);
        return repository.findByRecipeId(recipeId)
                .orElseThrow(() -> new ResourceNotFoundException("No photo set for recipe: " + recipeId));
    }

    @Override
    public void upload(Long recipeId, MultipartFile file) {
        Recipe recipe = getOwnedRecipe(recipeId);
        BufferedImage source = ImageReencoder.decode(inputStream(file));

        RecipeImage image = repository.findByRecipeId(recipeId)
                .orElseGet(() -> {
                    RecipeImage created = new RecipeImage();
                    created.setRecipe(recipe);
                    return created;
                });
        image.setImage(ImageReencoder.resizedJpeg(source, MAIN_MAX_SIDE));
        image.setThumbnail(ImageReencoder.squareJpeg(source, THUMBNAIL_SIZE));
        image.setContentType(ImageReencoder.CONTENT_TYPE);
        Instant now = Instant.now();
        image.setUpdatedAt(now);
        repository.save(image);

        touchRecipe(recipe, now);
    }

    @Override
    public void delete(Long recipeId) {
        Recipe recipe = getOwnedRecipe(recipeId);
        repository.deleteByRecipeId(recipeId);
        touchRecipe(recipe, null);
    }

    private Recipe getOwnedRecipe(Long recipeId) {
        return recipeRepository.findByIdAndUserId(recipeId, currentUserProvider.getUserId())
                .orElseThrow(() -> new ResourceNotFoundException("Recipe not found: " + recipeId));
    }

    /**
     * Bumps the recipe's own updatedAt (so the delta-sync feed picks up the
     * change) and imageUpdatedAt (so clients know specifically to re-download
     * the photo) — same reasoning as RecipeServiceImpl#update bumping updatedAt
     * explicitly for ingredient-only edits. Also live-syncs the change to every
     * client's already-assigned copy, same as any other recipe edit.
     */
    private void touchRecipe(Recipe recipe, Instant imageUpdatedAt) {
        recipe.setUpdatedAt(Instant.now());
        recipe.setImageUpdatedAt(imageUpdatedAt);
        eventPublisher.publishEvent(new RecipeUpdatedEvent(currentUserProvider.getUserId(), recipe.getId()));
    }

    private InputStream inputStream(MultipartFile file) {
        try {
            return file.getInputStream();
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }
}

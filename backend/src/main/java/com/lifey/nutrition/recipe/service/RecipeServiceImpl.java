package com.lifey.nutrition.recipe.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.nutrition.food.Food;
import com.lifey.nutrition.food.FoodRepository;
import com.lifey.nutrition.recipe.Recipe;
import com.lifey.nutrition.recipe.RecipeIngredient;
import com.lifey.nutrition.recipe.RecipeMapper;
import com.lifey.nutrition.recipe.RecipeRepository;
import com.lifey.nutrition.recipe.RecipeUpdatedEvent;
import com.lifey.nutrition.recipe.dto.RecipeIngredientRequest;
import com.lifey.nutrition.recipe.dto.RecipeRequest;
import com.lifey.nutrition.recipe.dto.RecipeResponse;
import com.lifey.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional
public class RecipeServiceImpl implements RecipeService {

    private final RecipeRepository recipeRepository;
    private final FoodRepository foodRepository;
    private final UserRepository userRepository;
    private final CurrentUserProvider currentUserProvider;
    private final ApplicationEventPublisher eventPublisher;

    @Override
    @Transactional(readOnly = true)
    public List<RecipeResponse> findAll() {
        return recipeRepository.findAllByUserIdAndDeletedAtIsNullOrderByFavoriteDescNameAsc(currentUserProvider.getUserId()).stream()
                .map(RecipeMapper::toResponse)
                .toList();
    }

    @Override
    @Transactional(readOnly = true)
    public Page<RecipeResponse> findPage(Pageable pageable, String search) {
        Long userId = currentUserProvider.getUserId();
        Page<Recipe> page = (search == null || search.isBlank())
                ? recipeRepository.findByUserIdAndDeletedAtIsNull(userId, pageable)
                : recipeRepository.findByUserIdAndDeletedAtIsNullAndNameContainingIgnoreCase(
                userId, search.trim(), pageable);
        return page.map(RecipeMapper::toResponse);
    }

    @Override
    @Transactional(readOnly = true)
    public Page<RecipeResponse> findDelta(Instant updatedSince, Pageable pageable) {
        // Delta-sync feed: fixed ordering, includes tombstoned rows — see
        // docs/16-delta-sync-rollout.md and RecipeRepository.findByUserIdAndUpdatedAtGreaterThanEqual.
        Pageable deltaPageable = PageRequest.of(
                pageable.getPageNumber(),
                pageable.getPageSize(),
                Sort.by(Sort.Order.asc("updatedAt"), Sort.Order.asc("id")));
        return recipeRepository.findByUserIdAndUpdatedAtGreaterThanEqual(currentUserProvider.getUserId(), updatedSince, deltaPageable)
                .map(RecipeMapper::toResponse);
    }

    @Override
    @Transactional(readOnly = true)
    public RecipeResponse findById(Long id) {
        return RecipeMapper.toResponse(getOrThrow(id));
    }

    @Override
    public RecipeResponse create(RecipeRequest request) {
        Recipe recipe = new Recipe();
        recipe.setUser(userRepository.getReferenceById(currentUserProvider.getUserId()));
        recipe.setName(request.name());
        recipe.setDescription(request.description());
        recipe.setFavorite(request.favorite());
        recipe.setServings(servingsOrDefault(request));
        replaceIngredients(recipe, request.ingredients());
        return RecipeMapper.toResponse(recipeRepository.save(recipe));
    }

    @Override
    public RecipeResponse update(Long id, RecipeRequest request) {
        Recipe recipe = getOrThrow(id);
        recipe.setName(request.name());
        recipe.setDescription(request.description());
        recipe.setFavorite(request.favorite());
        recipe.setServings(servingsOrDefault(request));
        replaceIngredients(recipe, request.ingredients());
        // Ingredients are child rows with no delta feed of their own (docs/16 §2.3) —
        // an ingredient-only edit (e.g. quantity changed, food swapped, name/description
        // unchanged) would leave Recipe's own scalar fields untouched, so Hibernate's
        // dirty-checking could skip @PreUpdate. Bump explicitly so it always fires.
        recipe.setUpdatedAt(Instant.now());
        // Live-sync: push this edit to every client's already-assigned copy
        // (see AssignedContentSyncListener).
        eventPublisher.publishEvent(new RecipeUpdatedEvent(currentUserProvider.getUserId(), recipe.getId()));
        return RecipeMapper.toResponse(recipe);
    }

    @Override
    public void delete(Long id) {
        Recipe recipe = getOrThrow(id);
        recipe.setDeletedAt(Instant.now());
    }

    private static int servingsOrDefault(RecipeRequest request) {
        return request.servings() != null ? request.servings() : 1;
    }

    private Recipe getOrThrow(Long id) {
        return recipeRepository.findByIdAndUserId(id, currentUserProvider.getUserId())
                .orElseThrow(() -> new ResourceNotFoundException("Recipe not found: " + id));
    }

    /**
     * Rebuilds the recipe's ingredient list from the request, resolving each
     * {@code foodId}. Relies on {@code orphanRemoval} to delete dropped ingredients.
     */
    private void replaceIngredients(Recipe recipe, List<RecipeIngredientRequest> requested) {
        recipe.getIngredients().clear();
        for (RecipeIngredientRequest item : requested) {
            Food food = foodRepository.findByIdAndUserId(item.foodId(), currentUserProvider.getUserId())
                    .orElseThrow(() -> new ResourceNotFoundException("Food not found: " + item.foodId()));

            RecipeIngredient ingredient = new RecipeIngredient();
            ingredient.setRecipe(recipe);
            ingredient.setFood(food);
            ingredient.setQuantityInGrams(item.quantityInGrams());
            recipe.getIngredients().add(ingredient);
        }
    }
}

package com.lifey.nutrition.recipe;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.nutrition.food.Food;
import com.lifey.nutrition.food.FoodRepository;
import com.lifey.nutrition.recipe.dto.RecipeIngredientRequest;
import com.lifey.nutrition.recipe.dto.RecipeRequest;
import com.lifey.nutrition.recipe.dto.RecipeResponse;
import com.lifey.user.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@Transactional
public class RecipeServiceImpl implements RecipeService {

    private final RecipeRepository recipeRepository;
    private final FoodRepository foodRepository;
    private final UserRepository userRepository;
    private final CurrentUserProvider currentUserProvider;

    public RecipeServiceImpl(RecipeRepository recipeRepository, FoodRepository foodRepository,
                             UserRepository userRepository, CurrentUserProvider currentUserProvider) {
        this.recipeRepository = recipeRepository;
        this.foodRepository = foodRepository;
        this.userRepository = userRepository;
        this.currentUserProvider = currentUserProvider;
    }

    @Override
    @Transactional(readOnly = true)
    public List<RecipeResponse> findAll() {
        return recipeRepository.findAllByUserIdOrderByFavoriteDescNameAsc(currentUserProvider.getUserId()).stream()
                .map(RecipeMapper::toResponse)
                .toList();
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
        replaceIngredients(recipe, request.ingredients());
        return RecipeMapper.toResponse(recipeRepository.save(recipe));
    }

    @Override
    public RecipeResponse update(Long id, RecipeRequest request) {
        Recipe recipe = getOrThrow(id);
        recipe.setName(request.name());
        recipe.setDescription(request.description());
        recipe.setFavorite(request.favorite());
        replaceIngredients(recipe, request.ingredients());
        return RecipeMapper.toResponse(recipe);
    }

    @Override
    public void delete(Long id) {
        Long userId = currentUserProvider.getUserId();
        if (!recipeRepository.existsByIdAndUserId(id, userId)) {
            throw new ResourceNotFoundException("Recipe not found: " + id);
        }
        recipeRepository.deleteByIdAndUserId(id, userId);
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
            Food food = foodRepository.findById(item.foodId())
                    .orElseThrow(() -> new ResourceNotFoundException("Food not found: " + item.foodId()));

            RecipeIngredient ingredient = new RecipeIngredient();
            ingredient.setRecipe(recipe);
            ingredient.setFood(food);
            ingredient.setQuantityInGrams(item.quantityInGrams());
            recipe.getIngredients().add(ingredient);
        }
    }
}

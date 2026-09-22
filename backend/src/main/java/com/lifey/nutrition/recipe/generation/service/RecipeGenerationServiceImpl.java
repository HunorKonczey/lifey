package com.lifey.nutrition.recipe.generation.service;

import com.lifey.ai.AiFeatureGate;
import com.lifey.ai.exception.AiUnavailableException;
import com.lifey.auth.CurrentUserProvider;
import com.lifey.billing.service.AiUsageCounterService;
import com.lifey.nutrition.food.Food;
import com.lifey.nutrition.food.FoodRepository;
import com.lifey.nutrition.recipe.generation.client.GeneratedRecipe;
import com.lifey.nutrition.recipe.generation.client.RecipeGenerator;
import com.lifey.nutrition.recipe.generation.dto.GeneratedIngredientResponse;
import com.lifey.nutrition.recipe.generation.dto.GeneratedRecipeResponse;
import com.lifey.nutrition.recipe.generation.dto.MacroTotals;
import com.lifey.nutrition.recipe.generation.dto.RecipeGenerationRequest;
import com.lifey.nutrition.recipe.generation.exception.InvalidGenerationRequestException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

/**
 * Gate, then call, then count — the same order and the same reasoning as the
 * meal estimate (docs/23-ai-calorie-estimation-plan.md). Between the call and
 * the count sits the part specific to recipes: never trusting the ids the model
 * emitted, and not letting it create a second "Chicken breast" in a catalog
 * that already has one.
 *
 * <p>Deliberately not {@code @Transactional}: the model call takes seconds and
 * must not hold a connection, and the usage increment commits on its own so
 * nothing after a successful call can roll it back.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class RecipeGenerationServiceImpl implements RecipeGenerationService {

    /**
     * How many of the user's foods the prompt carries. A personal catalog is
     * usually far smaller; the cap stops a user with thousands of foods from
     * paying for a prompt that big. Alphabetical, so the snapshot is stable
     * between two generations.
     */
    static final int CATALOG_LIMIT = 300;

    static final int MAX_INGREDIENTS = 20;
    static final double MAX_QUANTITY_GRAMS = 3000;
    /** Pure fat is ~900 kcal/100 g; nothing edible is above it. */
    static final double MAX_CALORIES_PER_100G = 900;
    static final int MAX_SERVINGS = 12;
    static final int MAX_NAME_LENGTH = 100;
    /** {@code recipes.description} is 2000; the prompt asks for 1800. */
    static final int MAX_DESCRIPTION_LENGTH = 2000;

    private final AiFeatureGate aiFeatureGate;
    private final RecipeGenerator generator;
    private final FoodRepository foodRepository;
    private final AiUsageCounterService aiUsageCounterService;
    private final CurrentUserProvider currentUserProvider;

    @Override
    public GeneratedRecipeResponse generate(RecipeGenerationRequest request) {
        if (request.hasMeatTypeConflict()) {
            throw new InvalidGenerationRequestException(
                    "A meat type cannot be combined with the " + request.dietType() + " diet");
        }
        Long userId = currentUserProvider.getUserId();
        aiFeatureGate.checkRecipeGeneration(userId);

        // Spring Data opens its own transaction for this read; the model call
        // that follows must not sit inside one.
        List<Food> catalog = foodRepository.findAllByUserIdAndHiddenFalseOrderByName(userId);
        GeneratedRecipe generated = generator.generate(request, snapshot(catalog));
        GeneratedRecipeResponse response = toResponse(generated, catalog);

        recordUsage(userId);
        return response;
    }

    /** {@code id | name | kcal/100g} per line — the format the prompt documents. */
    static String snapshot(List<Food> catalog) {
        return catalog.stream()
                .limit(CATALOG_LIMIT)
                .map(food -> "%d | %s | %.0f".formatted(food.getId(), food.getName(), food.getCaloriesPer100g()))
                .collect(Collectors.joining("\n"));
    }

    /**
     * The user already has a good proposal at this point; losing it over a
     * failed counter write would be worse than one uncounted call.
     */
    private void recordUsage(Long userId) {
        try {
            aiUsageCounterService.recordUsage(userId);
        } catch (RuntimeException e) {
            log.error("Could not record AI usage for user {} after a successful recipe generation", userId, e);
        }
    }

    static GeneratedRecipeResponse toResponse(GeneratedRecipe generated, List<Food> catalog) {
        Map<Long, Food> byId = catalog.stream()
                .collect(Collectors.toMap(Food::getId, Function.identity(), (a, _) -> a, LinkedHashMap::new));
        Map<String, Food> byName = catalog.stream()
                .collect(Collectors.toMap(food -> food.getName().toLowerCase(Locale.ROOT),
                        Function.identity(), (a, _) -> a, LinkedHashMap::new));

        List<GeneratedIngredientResponse> ingredients = new ArrayList<>();
        for (GeneratedRecipe.Ingredient ingredient : generated.ingredients() == null
                ? List.<GeneratedRecipe.Ingredient>of() : generated.ingredients()) {
            GeneratedIngredientResponse mapped = toIngredient(ingredient, byId, byName);
            if (mapped != null) ingredients.add(mapped);
            if (ingredients.size() == MAX_INGREDIENTS) break;
        }
        if (ingredients.isEmpty()) {
            throw new AiUnavailableException("Model returned no usable ingredients");
        }

        int servings = Math.clamp(generated.servings(), 1, MAX_SERVINGS);
        return new GeneratedRecipeResponse(
                trim(generated.name(), MAX_NAME_LENGTH),
                trim(generated.description(), MAX_DESCRIPTION_LENGTH),
                servings,
                ingredients,
                perServing(ingredients, byId, servings));
    }

    /**
     * Two guards on top of the model's own matching. An {@code existingFoodId}
     * is only believed when it is one of <em>this</em> user's visible foods —
     * a model-emitted id is input, not authority. And a proposed new food whose
     * name the user already has becomes a reference to that food instead, so
     * the catalog doesn't grow a second copy over a spelling difference.
     *
     * @return null when the ingredient can't be used at all
     */
    private static GeneratedIngredientResponse toIngredient(GeneratedRecipe.Ingredient ingredient,
                                                            Map<Long, Food> byId,
                                                            Map<String, Food> byName) {
        double grams = ingredient.quantityInGrams();
        if (ingredient.name() == null || ingredient.name().isBlank()
                || !Double.isFinite(grams) || grams <= 0) {
            return null;
        }
        grams = round(Math.min(grams, MAX_QUANTITY_GRAMS));

        if (ingredient.claimsExistingFood()) {
            Food food = byId.get(ingredient.existingFoodId());
            if (food != null) {
                return existing(food, grams);
            }
            // A hallucinated or foreign id: fall through and treat it as a new
            // food, which the name check below may still resolve to a real one.
        }
        Food sameName = byName.get(ingredient.name().strip().toLowerCase(Locale.ROOT));
        if (sameName != null) {
            return existing(sameName, grams);
        }
        double calories = sanitize(ingredient.caloriesPer100g(), MAX_CALORIES_PER_100G);
        if (calories <= 0 && ingredient.proteinPer100g() <= 0
                && ingredient.carbsPer100g() <= 0 && ingredient.fatPer100g() <= 0) {
            // Claimed an existing food we don't have, and gave no values of its
            // own — there is nothing to log for this ingredient.
            return null;
        }
        return new GeneratedIngredientResponse(null,
                new GeneratedIngredientResponse.NewFood(
                        trim(ingredient.name(), MAX_NAME_LENGTH),
                        round(calories),
                        round(sanitize(ingredient.proteinPer100g(), 100)),
                        round(sanitize(ingredient.carbsPer100g(), 100)),
                        round(sanitize(ingredient.fatPer100g(), 100))),
                trim(ingredient.name(), MAX_NAME_LENGTH),
                grams);
    }

    private static GeneratedIngredientResponse existing(Food food, double grams) {
        return new GeneratedIngredientResponse(food.getId(), null, food.getName(), grams);
    }

    /**
     * Computed here rather than taken from the model: it is arithmetic over
     * values the client is about to save, so the preview must not disagree with
     * what the saved recipe will show.
     */
    private static MacroTotals perServing(List<GeneratedIngredientResponse> ingredients,
                                          Map<Long, Food> byId, int servings) {
        double calories = 0;
        double protein = 0;
        double carbs = 0;
        double fat = 0;
        for (GeneratedIngredientResponse ingredient : ingredients) {
            double factor = ingredient.quantityInGrams() / 100 / servings;
            if (ingredient.existingFoodId() != null) {
                Food food = byId.get(ingredient.existingFoodId());
                calories += food.getCaloriesPer100g() * factor;
                protein += food.getProteinPer100g() * factor;
                carbs += orZero(food.getCarbsPer100g()) * factor;
                fat += orZero(food.getFatPer100g()) * factor;
            } else {
                GeneratedIngredientResponse.NewFood food = ingredient.newFood();
                calories += food.caloriesPer100g() * factor;
                protein += food.proteinPer100g() * factor;
                carbs += food.carbsPer100g() * factor;
                fat += food.fatPer100g() * factor;
            }
        }
        return new MacroTotals(round(calories), round(protein), round(carbs), round(fat));
    }

    private static double orZero(Double value) {
        return value == null ? 0 : value;
    }

    private static double sanitize(double value, double max) {
        return Double.isFinite(value) && value > 0 ? Math.min(value, max) : 0;
    }

    private static double round(double value) {
        return Math.round(value * 10) / 10.0;
    }

    private static String trim(String value, int maxLength) {
        if (value == null) return null;
        String stripped = value.strip();
        return stripped.length() <= maxLength ? stripped : stripped.substring(0, maxLength).strip();
    }
}

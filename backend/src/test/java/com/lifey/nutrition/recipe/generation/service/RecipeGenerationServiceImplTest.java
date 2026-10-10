package com.lifey.nutrition.recipe.generation.service;

import com.lifey.ai.AiFeatureGate;
import com.lifey.ai.exception.AiCreditsExhaustedException;
import com.lifey.ai.exception.AiUnavailableException;
import com.lifey.auth.CurrentUserProvider;
import com.lifey.billing.service.AiUsageCounterService;
import com.lifey.nutrition.food.Food;
import com.lifey.nutrition.food.FoodRepository;
import com.lifey.nutrition.recipe.generation.client.GeneratedRecipe;
import com.lifey.nutrition.recipe.generation.client.RecipeGenerator;
import com.lifey.nutrition.recipe.generation.dto.CalorieBand;
import com.lifey.nutrition.recipe.generation.dto.DietType;
import com.lifey.nutrition.recipe.generation.dto.GeneratedIngredientResponse;
import com.lifey.nutrition.recipe.generation.dto.GeneratedRecipeResponse;
import com.lifey.nutrition.recipe.generation.dto.MealType;
import com.lifey.nutrition.recipe.generation.dto.MeatType;
import com.lifey.nutrition.recipe.generation.dto.RecipeGenerationRequest;
import com.lifey.nutrition.recipe.generation.exception.InvalidGenerationRequestException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class RecipeGenerationServiceImplTest {

    private static final Long USER_ID = 42L;
    private static final RecipeGenerationRequest REQUEST = new RecipeGenerationRequest(
            DietType.MEAT, MealType.DINNER, CalorieBand.FROM_500_TO_700, MeatType.CHICKEN, null);

    @Mock
    AiFeatureGate aiFeatureGate;

    @Mock
    RecipeGenerator generator;

    @Mock
    FoodRepository foodRepository;

    @Mock
    AiUsageCounterService aiUsageCounterService;

    @Mock
    CurrentUserProvider currentUserProvider;

    RecipeGenerationServiceImpl service;

    @BeforeEach
    void setUp() {
        service = new RecipeGenerationServiceImpl(
                aiFeatureGate, generator, foodRepository, aiUsageCounterService, currentUserProvider);
        lenient().when(currentUserProvider.getUserId()).thenReturn(USER_ID);
    }

    static Food food(long id, String name, double kcal, double protein, Double carbs, Double fat) {
        Food food = new Food();
        ReflectionTestUtils.setField(food, "id", id);
        food.setName(name);
        food.setCaloriesPer100g(kcal);
        food.setProteinPer100g(protein);
        food.setCarbsPer100g(carbs);
        food.setFatPer100g(fat);
        return food;
    }

    static GeneratedRecipe.Ingredient existing(long id, String name, double grams) {
        return new GeneratedRecipe.Ingredient(name, grams, id, 0, 0, 0, 0);
    }

    static GeneratedRecipe.Ingredient proposed(String name, double grams, double kcal, double protein,
                                               double carbs, double fat) {
        return new GeneratedRecipe.Ingredient(name, grams, 0, kcal, protein, carbs, fat);
    }

    private void givenCatalog(Food... foods) {
        when(foodRepository.findAllByUserIdAndHiddenFalseOrderByName(USER_ID)).thenReturn(List.of(foods));
    }

    private void givenGenerated(GeneratedRecipe recipe) {
        when(generator.generate(eq(REQUEST), anyString())).thenReturn(recipe);
    }

    static GeneratedRecipe.Ingredient proposedWithFibre(String name, double grams, double kcal, double fiber, double sugar) {
        return new GeneratedRecipe.Ingredient(name, grams, 0, kcal, 5.0, 60.0, 2.0, fiber, sugar);
    }

    @Test
    void perServing_fibreAndSugarComeFromTheModelsEstimateForNewFoodsAndAreKept_onTheNewFood() {
        givenCatalog();
        givenGenerated(new GeneratedRecipe("Oat bowl", "1. Mix.", 2, List.of(
                proposedWithFibre("Oats", 100, 370, 10.0, 1.0),
                proposedWithFibre("Apple", 200, 52, 2.4, 10.0))));

        GeneratedRecipeResponse response = service.generate(REQUEST);

        // per serving: (100 g oats + 200 g apple) / 2 servings
        assertThat(response.perServing().fiberGrams()).isEqualTo(7.4); // (10 + 4.8) / 2
        assertThat(response.perServing().sugarGrams()).isEqualTo(10.5); // (1 + 20) / 2
        assertThat(response.perServing().fiberSugarPartial()).isFalse();
        assertThat(response.ingredients().get(0).newFood().fiberPer100g()).isEqualTo(10.0);
        assertThat(response.ingredients().get(1).newFood().sugarPer100g()).isEqualTo(10.0);
    }

    @Test
    void perServing_anExistingFoodWithoutAFigure_addsNothing_andMakesTheTotalPartial() {
        Food chicken = food(7, "Chicken breast", 165, 31.0, 0.0, 3.6); // no fibre / sugar on file
        Food oats = food(8, "Oats", 370, 13.0, 60.0, 7.0);
        oats.setFiberPer100g(10.0);
        oats.setSugarPer100g(1.0);
        givenCatalog(chicken, oats);
        givenGenerated(new GeneratedRecipe("Mixed", "1. Cook.", 1, List.of(
                existing(7, "Chicken breast", 200), existing(8, "Oats", 50))));

        GeneratedRecipeResponse response = service.generate(REQUEST);

        assertThat(response.perServing().fiberGrams()).isEqualTo(5.0);
        assertThat(response.perServing().sugarGrams()).isEqualTo(0.5);
        assertThat(response.perServing().fiberSugarPartial()).isTrue();
    }

    @Test
    void perServing_whenNoExistingFoodHasAFigure_fibreAndSugarAreNull_notZero() {
        Food chicken = food(7, "Chicken breast", 165, 31.0, 0.0, 3.6);
        givenCatalog(chicken);
        givenGenerated(new GeneratedRecipe("Plain chicken", "1. Cook.", 1, List.of(existing(7, "Chicken breast", 200))));

        GeneratedRecipeResponse response = service.generate(REQUEST);

        assertThat(response.perServing().fiberGrams()).isNull();
        assertThat(response.perServing().sugarGrams()).isNull();
        assertThat(response.perServing().fiberSugarPartial()).isFalse();
    }

    @Test
    void aNewFoodsImplausibleFibreAndSugar_areClampedAndNegativeOnesDropToZero() {
        givenCatalog();
        givenGenerated(new GeneratedRecipe("Odd", "1. Mix.", 1, List.of(
                proposedWithFibre("Weird", 100, 100, 450.0, -3.0))));

        GeneratedRecipeResponse response = service.generate(REQUEST);

        GeneratedIngredientResponse.NewFood food = response.ingredients().get(0).newFood();
        assertThat(food.fiberPer100g()).isEqualTo(100.0);
        assertThat(food.sugarPer100g()).isZero();
    }

    @Test
    void generate_countsOneCreditAndKeepsBothIngredientShapes() {
        givenCatalog(food(7, "Chicken breast", 165, 31.0, 0.0, 3.6));
        givenGenerated(new GeneratedRecipe("Chicken and rice", "1. Cook it.", 2, List.of(
                existing(7, "Chicken breast", 300),
                proposed("Jasmine rice", 150, 355, 7.0, 78.0, 0.6))));

        GeneratedRecipeResponse response = service.generate(REQUEST);

        assertThat(response.name()).isEqualTo("Chicken and rice");
        assertThat(response.servings()).isEqualTo(2);
        assertThat(response.ingredients()).hasSize(2);
        assertThat(response.ingredients().get(0))
                .isEqualTo(new GeneratedIngredientResponse(7L, null, "Chicken breast", 300));
        assertThat(response.ingredients().get(1).existingFoodId()).isNull();
        assertThat(response.ingredients().get(1).newFood().name()).isEqualTo("Jasmine rice");
        verify(aiFeatureGate).checkRecipeGeneration(USER_ID);
        verify(aiUsageCounterService).recordUsage(USER_ID);
    }

    @Test
    void generate_perServingIsComputedFromTheCatalogValuesNotTheModels() {
        // The model left the per-100 g fields at 0 for the existing food, as instructed.
        givenCatalog(food(7, "Chicken breast", 165, 31.0, 0.0, 3.6));
        givenGenerated(new GeneratedRecipe("Chicken", "1. Cook it.", 2, List.of(
                existing(7, "Chicken breast", 400))));

        GeneratedRecipeResponse response = service.generate(REQUEST);

        // 400 g × 165 kcal/100 g ÷ 2 servings
        assertThat(response.perServing().calories()).isEqualTo(330);
        assertThat(response.perServing().proteinGrams()).isEqualTo(62);
        assertThat(response.perServing().fatGrams()).isEqualTo(7.2);
        assertThat(response.perServing().carbsGrams()).isZero();
    }

    @Test
    void generate_foreignOrInventedIdIsNotTrusted() {
        givenCatalog(food(7, "Chicken breast", 165, 31.0, 0.0, 3.6));
        givenGenerated(new GeneratedRecipe("Beef stew", "1. Cook it.", 2, List.of(
                // id 999 belongs to nobody in this catalog, but it came with values
                new GeneratedRecipe.Ingredient("Beef chuck", 500, 999, 250, 26, 0, 16))));

        GeneratedRecipeResponse response = service.generate(REQUEST);

        GeneratedIngredientResponse ingredient = response.ingredients().getFirst();
        assertThat(ingredient.existingFoodId()).isNull();
        assertThat(ingredient.newFood().caloriesPer100g()).isEqualTo(250);
    }

    @Test
    void generate_proposedFoodTheUserAlreadyHasBecomesAReference() {
        givenCatalog(food(7, "Chicken Breast", 165, 31.0, 0.0, 3.6));
        givenGenerated(new GeneratedRecipe("Chicken", "1. Cook it.", 1, List.of(
                proposed("  chicken breast  ", 200, 999, 99, 99, 99))));

        GeneratedIngredientResponse ingredient = service.generate(REQUEST).ingredients().getFirst();

        assertThat(ingredient.existingFoodId()).isEqualTo(7L);
        assertThat(ingredient.newFood()).isNull();
        // The catalog's own name wins over the model's spelling.
        assertThat(ingredient.name()).isEqualTo("Chicken Breast");
    }

    @Test
    void generate_dropsIngredientsThatCannotBeLogged() {
        givenCatalog(food(7, "Chicken breast", 165, 31.0, 0.0, 3.6));
        givenGenerated(new GeneratedRecipe("Chicken", "1. Cook it.", 1, List.of(
                existing(7, "Chicken breast", 200),
                proposed("Salt", 0, 0, 0, 0, 0),
                proposed("  ", 50, 100, 1, 1, 1),
                new GeneratedRecipe.Ingredient("Ghost food", 100, 999, 0, 0, 0, 0))));

        assertThat(service.generate(REQUEST).ingredients())
                .singleElement()
                .extracting(GeneratedIngredientResponse::name)
                .isEqualTo("Chicken breast");
    }

    @Test
    void generate_nothingUsableIsAFailedCallAndCostsNoCredit() {
        givenCatalog();
        givenGenerated(new GeneratedRecipe("Nothing", "1. Wait.", 1, List.of(
                proposed("Water", 0, 0, 0, 0, 0))));

        assertThatThrownBy(() -> service.generate(REQUEST)).isInstanceOf(AiUnavailableException.class);

        verify(aiUsageCounterService, never()).recordUsage(any());
    }

    @Test
    void generate_clampsImplausibleValues() {
        givenCatalog();
        givenGenerated(new GeneratedRecipe("Big", "1. Cook.", 99, List.of(
                proposed("Oil", 99999, 99999, -5, Double.NaN, 100))));

        GeneratedRecipeResponse response = service.generate(REQUEST);

        assertThat(response.servings()).isEqualTo(12);
        GeneratedIngredientResponse ingredient = response.ingredients().getFirst();
        assertThat(ingredient.quantityInGrams()).isEqualTo(3000);
        assertThat(ingredient.newFood().caloriesPer100g()).isEqualTo(900);
        assertThat(ingredient.newFood().proteinPer100g()).isZero();
        assertThat(ingredient.newFood().carbsPer100g()).isZero();
    }

    @Test
    void generate_sendsTheCatalogSnapshotToTheModel() {
        givenCatalog(food(7, "Chicken breast", 165, 31.0, 0.0, 3.6),
                food(9, "Olive oil", 884, 0.0, 0.0, 100.0));
        givenGenerated(new GeneratedRecipe("Chicken", "1. Cook it.", 1, List.of(
                existing(7, "Chicken breast", 200))));
        ArgumentCaptor<String> catalog = ArgumentCaptor.forClass(String.class);

        service.generate(REQUEST);

        verify(generator).generate(eq(REQUEST), catalog.capture());
        assertThat(catalog.getValue()).isEqualTo("7 | Chicken breast | 165\n9 | Olive oil | 884");
    }

    @Test
    void generate_meatTypeWithAVeganDietIsRejectedBeforeAnythingElse() {
        RecipeGenerationRequest vegan = new RecipeGenerationRequest(
                DietType.VEGAN, MealType.LUNCH, CalorieBand.UNDER_300, MeatType.BEEF, null);

        assertThatThrownBy(() -> service.generate(vegan))
                .isInstanceOf(InvalidGenerationRequestException.class);

        verifyNoInteractions(aiFeatureGate, generator, foodRepository, aiUsageCounterService);
    }

    @Test
    void generate_gateRejects_neitherCallsModelNorCounts() {
        doThrow(new AiCreditsExhaustedException()).when(aiFeatureGate).checkRecipeGeneration(USER_ID);

        assertThatThrownBy(() -> service.generate(REQUEST)).isInstanceOf(AiCreditsExhaustedException.class);

        verifyNoInteractions(generator, aiUsageCounterService);
    }

    @Test
    void generate_modelFails_doesNotBurnACredit() {
        givenCatalog();
        when(generator.generate(any(), anyString())).thenThrow(new AiUnavailableException("down"));

        assertThatThrownBy(() -> service.generate(REQUEST)).isInstanceOf(AiUnavailableException.class);

        verify(aiUsageCounterService, never()).recordUsage(any());
    }

    @Test
    void generate_counterFailure_stillReturnsTheProposal() {
        givenCatalog();
        givenGenerated(new GeneratedRecipe("Rice", "1. Boil.", 1, List.of(
                proposed("Rice", 100, 355, 7, 78, 0.6))));
        doThrow(new IllegalStateException("db down")).when(aiUsageCounterService).recordUsage(USER_ID);

        assertThat(service.generate(REQUEST).ingredients()).hasSize(1);
    }
}

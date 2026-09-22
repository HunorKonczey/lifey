package com.lifey.nutrition.recipe.generation.client;

import com.anthropic.client.AnthropicClient;
import com.anthropic.client.okhttp.AnthropicOkHttpClient;
import com.lifey.ai.AiProperties;
import com.lifey.nutrition.recipe.generation.dto.CalorieBand;
import com.lifey.nutrition.recipe.generation.dto.DietType;
import com.lifey.nutrition.recipe.generation.dto.MealType;
import com.lifey.nutrition.recipe.generation.dto.MeatType;
import com.lifey.nutrition.recipe.generation.dto.RecipeGenerationRequest;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.ObjectProvider;

import java.time.Duration;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * The manual smoke test for Phase 2 (docs/23-ai-calorie-estimation-plan.md):
 * real Claude API calls, real money. Skipped unless {@code ANTHROPIC_API_KEY}
 * is set; {@code LIFEY_AI_MODEL} picks the model (default
 * {@code claude-haiku-4-5}).
 *
 * <p>Two cases, because they fail differently: a vegan request against a
 * catalog that contains meat (does the diet rule beat the "reuse these foods"
 * instruction?), and a meat request with no catalog at all (a brand-new user,
 * where everything must come back as a new food). Quality is the reader's
 * judgement; only the contract is asserted.
 */
@EnabledIfEnvironmentVariable(named = "ANTHROPIC_API_KEY", matches = ".+")
class ClaudeRecipeGeneratorLiveTest {

    /** Ids and values a real catalog would have; meat included on purpose. */
    private static final String CATALOG = String.join("\n",
            "7 | Chicken breast | 165",
            "9 | Olive oil | 884",
            "11 | Red lentils | 352",
            "14 | Basmati rice | 349",
            "18 | Greek yoghurt | 59",
            "23 | Cheddar cheese | 402",
            "27 | Spinach | 23");

    @Test
    void veganLunchKeepsTheDietRuleAndReusesTheCatalog() {
        RecipeGenerationRequest request = new RecipeGenerationRequest(
                DietType.VEGAN, MealType.LUNCH, CalorieBand.FROM_300_TO_500, null, "high protein");

        GeneratedRecipe recipe = print(generator().generate(request, CATALOG), "vegan lunch, catalog of 7");

        assertThat(recipe.ingredients()).isNotEmpty();
        assertThat(recipe.ingredients()).noneSatisfy(ingredient -> {
            assertThat(ingredient.existingFoodId()).isIn(7L, 18L, 23L);   // chicken, yoghurt, cheddar
        });
        assertThat(recipe.description()).hasSizeLessThan(2000);
    }

    @Test
    void newUserWithNoFoodsGetsEverythingAsNewFoods() {
        RecipeGenerationRequest request = new RecipeGenerationRequest(
                DietType.MEAT, MealType.DINNER, CalorieBand.OVER_700, MeatType.BEEF, null);

        GeneratedRecipe recipe = print(generator().generate(request, ""), "beef dinner, empty catalog");

        assertThat(recipe.ingredients()).isNotEmpty();
        assertThat(recipe.ingredients()).allSatisfy(ingredient -> {
            assertThat(ingredient.existingFoodId()).isZero();
            assertThat(ingredient.caloriesPer100g()).isBetween(0.0, 900.0);
        });
    }

    private static GeneratedRecipe print(GeneratedRecipe recipe, String label) {
        System.out.printf("%n=== %s · %s · %d servings%n  %s%n",
                label, System.getenv().getOrDefault("LIFEY_AI_MODEL", "claude-haiku-4-5"),
                recipe.servings(), recipe.name());
        for (GeneratedRecipe.Ingredient ingredient : recipe.ingredients()) {
            System.out.printf("  %-28s %6.0f g  %s%n", ingredient.name(), ingredient.quantityInGrams(),
                    ingredient.claimsExistingFood()
                            ? "id " + ingredient.existingFoodId()
                            : "new · %.0f kcal/100g".formatted(ingredient.caloriesPer100g()));
        }
        System.out.println("  " + recipe.description().replace("\n", "\n  "));
        return recipe;
    }

    private static ClaudeRecipeGenerator generator() {
        AiProperties properties = new AiProperties(System.getenv("ANTHROPIC_API_KEY"),
                System.getenv().getOrDefault("LIFEY_AI_MODEL", "claude-haiku-4-5"), 60);
        AnthropicClient client = AnthropicOkHttpClient.builder()
                .apiKey(properties.apiKey())
                .timeout(Duration.ofSeconds(properties.timeoutSeconds()))
                .build();
        return new ClaudeRecipeGenerator(new SingletonProvider<>(client), properties);
    }

    /** The production bean comes from Spring; this test builds its own. */
    private record SingletonProvider<T>(T value) implements ObjectProvider<T> {

        @Override
        public T getObject() {
            return value;
        }

        @Override
        public T getIfAvailable() {
            return value;
        }

        @Override
        public T getObject(Object... args) {
            return value;
        }

        @Override
        public T getIfUnique() {
            return value;
        }
    }
}

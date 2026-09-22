package com.lifey.nutrition.recipe.generation.client;

import com.anthropic.client.AnthropicClient;
import com.anthropic.errors.AnthropicException;
import com.anthropic.errors.AnthropicIoException;
import com.anthropic.errors.AnthropicServiceException;
import com.anthropic.errors.InternalServerException;
import com.anthropic.errors.RateLimitException;
import com.anthropic.models.messages.MessageCreateParams;
import com.anthropic.models.messages.StopReason;
import com.anthropic.models.messages.StructuredMessage;
import com.anthropic.models.messages.StructuredMessageCreateParams;
import com.anthropic.models.messages.StructuredTextBlock;
import com.lifey.ai.AiProperties;
import com.lifey.ai.exception.AiNotConfiguredException;
import com.lifey.ai.exception.AiUnavailableException;
import com.lifey.nutrition.recipe.generation.dto.MeatType;
import com.lifey.nutrition.recipe.generation.dto.RecipeGenerationRequest;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.stereotype.Component;

/**
 * One Messages API call per recipe: the wizard's constraints plus the user's
 * food catalog, answered as schema-validated JSON
 * (docs/23-ai-calorie-estimation-plan.md Phase 2).
 *
 * <p>Text-only, so output tokens dominate — unlike the meal photo, where the
 * image does. Every SDK failure becomes {@link AiUnavailableException}; what
 * went wrong is logged here and never reaches the client.
 */
@Slf4j
@Component
public class ClaudeRecipeGenerator implements RecipeGenerator {

    /** Instructions plus ~15 ingredients of JSON, with headroom for a thinking model. */
    static final long MAX_TOKENS = 8_000L;

    static final String SYSTEM_PROMPT = """
            You design a single home-cooking recipe for a calorie-tracking app, from the user's \
            constraints. The user reviews and edits everything before saving.

            Hard rules, in this order:
            - The diet type is absolute. Never include an ingredient it forbids, not even a small \
            amount, and not as an optional garnish.
            - The calorie band is per serving, not for the whole recipe. Make the ingredient \
            quantities and the serving count land inside it.
            - Quantities are in grams for the whole recipe, realistic for home cooking, and include \
            the cooking fat.
            - Prefer everyday ingredients over specialities, and keep the list under 15 items.

            Reusing the user's foods. You get the user's food list as `id | name | kcal per 100 g`. \
            When an ingredient is one of those foods — the same food, minor naming differences \
            included — set existingFoodId to its id and leave the per-100 g values at 0; the app \
            uses its own stored values. Only when the list has nothing for that ingredient, set \
            existingFoodId to 0 and give realistic per-100 g values for it. An empty list is normal \
            for a new user: then everything is a new food.

            Nutrition values are per 100 g of the raw ingredient, must match at 4 kcal per gram of \
            protein and carbohydrate and 9 per gram of fat, and must be realistic for that food.

            Before you answer, add up the energy of every ingredient — grams times its per-100 g \
            value, divided by 100 — and divide the total by the serving count. If that number falls \
            outside the requested band, change the quantities or the serving count until it is \
            inside. For a food from the user's list, use the kcal value the list gives.

            The description is the preparation: numbered steps, plain text, no markdown, under 1800 \
            characters. Write it in English.""";

    private final ObjectProvider<AnthropicClient> client;
    private final AiProperties properties;

    public ClaudeRecipeGenerator(ObjectProvider<AnthropicClient> client, AiProperties properties) {
        this.client = client;
        this.properties = properties;
    }

    @Override
    public GeneratedRecipe generate(RecipeGenerationRequest request, String catalog) {
        AnthropicClient anthropic = client.getIfAvailable();
        if (anthropic == null) {
            throw new AiNotConfiguredException();
        }
        StructuredMessage<GeneratedRecipe> response = call(anthropic, buildParams(request, catalog));

        StopReason stopReason = response.stopReason().orElse(null);
        if (StopReason.REFUSAL.equals(stopReason)) {
            throw new AiUnavailableException("Model refused the recipe request");
        }
        if (StopReason.MAX_TOKENS.equals(stopReason)) {
            throw new AiUnavailableException("Model answer was cut off at max_tokens");
        }
        try {
            return response.content().stream()
                    .flatMap(block -> block.text().stream())
                    .map(StructuredTextBlock::text)
                    .findFirst()
                    .orElseThrow(() -> new AiUnavailableException("Model answer had no text block"));
        } catch (AnthropicException e) {
            throw new AiUnavailableException("Model answer did not match the recipe schema", e);
        }
    }

    StructuredMessageCreateParams<GeneratedRecipe> buildParams(RecipeGenerationRequest request, String catalog) {
        return MessageCreateParams.builder()
                .model(properties.model())
                .maxTokens(MAX_TOKENS)
                .system(SYSTEM_PROMPT)
                .outputConfig(GeneratedRecipe.class)
                .addUserMessage(userMessage(request, catalog))
                .build();
    }

    static String userMessage(RecipeGenerationRequest request, String catalog) {
        StringBuilder message = new StringBuilder()
                .append("Diet: ").append(request.dietType().promptDescription()).append('\n')
                .append("Meal: ").append(request.mealType().name().toLowerCase()).append('\n')
                .append("Calories per serving: ").append(request.calorieBand().promptDescription())
                .append('\n');
        if (request.meatType() != null) {
            message.append("Meat or fish to use: ")
                    .append(request.meatType() == MeatType.ANY
                            ? "your choice"
                            : request.meatType().name().toLowerCase())
                    .append('\n');
        }
        if (request.extraRequest() != null && !request.extraRequest().isBlank()) {
            // The user's own words, kept as data: the rules above are the system
            // prompt's, and a wish typed here cannot replace them.
            message.append("The user also asked, in their own words: \"")
                    .append(request.extraRequest().strip().replace("\"", "'"))
                    .append("\"\n");
        }
        message.append("\nThe user's foods (id | name | kcal per 100 g):\n")
                .append(catalog.isBlank() ? "(empty — this user has no foods yet)" : catalog);
        return message.toString();
    }

    private StructuredMessage<GeneratedRecipe> call(AnthropicClient anthropic,
                                                    StructuredMessageCreateParams<GeneratedRecipe> params) {
        try {
            return anthropic.messages().create(params);
        } catch (RateLimitException | InternalServerException e) {
            // Transient on the provider's side; the SDK has already retried.
            log.warn("Claude API unavailable ({}) for recipe generation", e.statusCode());
            throw new AiUnavailableException("Claude API unavailable", e);
        } catch (AnthropicServiceException e) {
            // 400/401/403/404: our request or our key is wrong. A bug or a
            // misconfiguration, so it is logged loudly rather than as a blip.
            log.error("Claude API rejected the recipe generation request ({})", e.statusCode(), e);
            throw new AiUnavailableException("Claude API rejected the request", e);
        } catch (AnthropicIoException e) {
            log.warn("Claude API network failure or timeout for recipe generation", e);
            throw new AiUnavailableException("Claude API timed out or was unreachable", e);
        } catch (AnthropicException e) {
            log.error("Claude API call failed for recipe generation", e);
            throw new AiUnavailableException("Claude API call failed", e);
        }
    }
}

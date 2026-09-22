package com.lifey.nutrition.estimation.client;

import com.anthropic.client.AnthropicClient;
import com.anthropic.errors.AnthropicException;
import com.anthropic.errors.AnthropicIoException;
import com.anthropic.errors.AnthropicServiceException;
import com.anthropic.errors.InternalServerException;
import com.anthropic.errors.RateLimitException;
import com.anthropic.models.messages.Base64ImageSource;
import com.anthropic.models.messages.ContentBlockParam;
import com.anthropic.models.messages.ImageBlockParam;
import com.anthropic.models.messages.MessageCreateParams;
import com.anthropic.models.messages.StopReason;
import com.anthropic.models.messages.StructuredMessage;
import com.anthropic.models.messages.StructuredMessageCreateParams;
import com.anthropic.models.messages.StructuredTextBlock;
import com.lifey.ai.AiProperties;
import com.lifey.ai.exception.AiNotConfiguredException;
import com.lifey.ai.exception.AiUnavailableException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.stereotype.Component;

import java.util.Base64;
import java.util.List;

/**
 * One Messages API call per photo: the image plus an instruction, answered as
 * schema-validated JSON through structured outputs, so there is no free-text
 * parsing (docs/23-ai-calorie-estimation-plan.md "Service flow").
 *
 * <p>Every SDK failure becomes {@link AiUnavailableException}; what actually
 * went wrong is logged here and never reaches the client.
 */
@Slf4j
@Component
public class ClaudeMealPhotoAnalyzer implements MealPhotoAnalyzer {

    /**
     * The JSON answer alone is a few hundred tokens (the default Haiku 4.5 doesn't
     * think). The headroom is for the larger models in docs/23 "Usable models",
     * which run adaptive thinking by default and count it against this limit.
     * Only the tokens actually generated are billed.
     */
    static final long MAX_TOKENS = 16_000L;

    static final String SYSTEM_PROMPT = """
            You estimate nutrition from a single photo of a meal, for a calorie-tracking app. \
            The user reviews and corrects every value before saving, so give your best realistic \
            estimate rather than declining when unsure.

            Identify each distinct food or drink item in the photo. For each, give a short English \
            name, the estimated portion in grams, and the calories, protein, carbohydrates and fat \
            for that portion (not per 100 g).

            Use plates, cutlery, hands and packaging for scale when visible. When a portion size is \
            ambiguous, estimate conservatively and lower the confidence. Account for visible cooking \
            fat, sauces and dressings, which often carry much of a meal's energy.

            Check every item before you answer:
            - Calories must match the macros: protein and carbohydrate are 4 kcal per gram, fat is 9. \
            Recompute if they disagree.
            - Calories per gram must fit the food. Raw vegetables and most fruit are 0.2-0.6, cooked \
            vegetables and soups 0.3-1, milk and yoghurt 0.4-1, cooked pasta, rice and potatoes 1-1.6, \
            bread 2.5-3, lean cooked meat and fish 1-2, fatty meat and cheese 3-4, pizza 2.4-2.9, \
            fried food 2.5-4, nuts, butter and oil 6-9. An item outside its range is wrong.
            - No macro can weigh more than the portion itself.

            If the photo contains no food, return an empty items list and say so briefly in notes. \
            Otherwise keep notes to one short sentence, or leave it empty.""";

    static final String USER_INSTRUCTION = "Estimate the foods in this photo.";

    private final ObjectProvider<AnthropicClient> client;
    private final AiProperties properties;

    public ClaudeMealPhotoAnalyzer(ObjectProvider<AnthropicClient> client, AiProperties properties) {
        this.client = client;
        this.properties = properties;
    }

    @Override
    public MealPhotoEstimate analyze(byte[] jpeg) {
        AnthropicClient anthropic = client.getIfAvailable();
        if (anthropic == null) {
            throw new AiNotConfiguredException();
        }
        StructuredMessage<MealPhotoEstimate> response = call(anthropic, buildParams(jpeg));

        StopReason stopReason = response.stopReason().orElse(null);
        if (StopReason.REFUSAL.equals(stopReason)) {
            throw new AiUnavailableException("Model refused the meal photo");
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
            throw new AiUnavailableException("Model answer did not match the estimate schema", e);
        }
    }

    StructuredMessageCreateParams<MealPhotoEstimate> buildParams(byte[] jpeg) {
        ImageBlockParam image = ImageBlockParam.builder()
                .source(Base64ImageSource.builder()
                        .mediaType(Base64ImageSource.MediaType.IMAGE_JPEG)
                        .data(Base64.getEncoder().encodeToString(jpeg))
                        .build())
                .build();
        return MessageCreateParams.builder()
                .model(properties.model())
                .maxTokens(MAX_TOKENS)
                .system(SYSTEM_PROMPT)
                .outputConfig(MealPhotoEstimate.class)
                .addUserMessageOfBlockParams(List.of(
                        ContentBlockParam.ofImage(image),
                        ContentBlockParam.ofText(USER_INSTRUCTION)))
                .build();
    }

    private StructuredMessage<MealPhotoEstimate> call(AnthropicClient anthropic,
                                                      StructuredMessageCreateParams<MealPhotoEstimate> params) {
        try {
            return anthropic.messages().create(params);
        } catch (RateLimitException | InternalServerException e) {
            // Transient on the provider's side; the SDK has already retried.
            log.warn("Claude API unavailable ({}) for meal estimation", e.statusCode());
            throw new AiUnavailableException("Claude API unavailable", e);
        } catch (AnthropicServiceException e) {
            // 400/401/403/404: our request or our key is wrong. A bug or a
            // misconfiguration, so it is logged loudly rather than as a blip.
            log.error("Claude API rejected the meal estimation request ({})", e.statusCode(), e);
            throw new AiUnavailableException("Claude API rejected the request", e);
        } catch (AnthropicIoException e) {
            log.warn("Claude API network failure or timeout for meal estimation", e);
            throw new AiUnavailableException("Claude API timed out or was unreachable", e);
        } catch (AnthropicException e) {
            log.error("Claude API call failed for meal estimation", e);
            throw new AiUnavailableException("Claude API call failed", e);
        }
    }
}

package com.lifey.nutrition.recipe.generation.client;

import com.anthropic.client.AnthropicClient;
import com.anthropic.errors.AnthropicIoException;
import com.anthropic.models.messages.MessageCreateParams;
import com.anthropic.models.messages.StopReason;
import com.anthropic.models.messages.StructuredContentBlock;
import com.anthropic.models.messages.StructuredMessage;
import com.anthropic.models.messages.StructuredMessageCreateParams;
import com.anthropic.models.messages.StructuredTextBlock;
import com.lifey.ai.AiProperties;
import com.lifey.ai.exception.AiNotConfiguredException;
import com.lifey.ai.exception.AiUnavailableException;
import com.lifey.nutrition.recipe.generation.dto.CalorieBand;
import com.lifey.nutrition.recipe.generation.dto.DietType;
import com.lifey.nutrition.recipe.generation.dto.MealType;
import com.lifey.nutrition.recipe.generation.dto.MeatType;
import com.lifey.nutrition.recipe.generation.dto.RecipeGenerationRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Answers;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.beans.factory.ObjectProvider;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ClaudeRecipeGeneratorTest {

    private static final AiProperties PROPERTIES = new AiProperties("sk-test", "claude-haiku-4-5", 60);
    private static final RecipeGenerationRequest REQUEST = new RecipeGenerationRequest(
            DietType.VEGETARIAN, MealType.LUNCH, CalorieBand.FROM_300_TO_500, null, "no mushrooms");
    private static final GeneratedRecipe RECIPE = new GeneratedRecipe("Lentil soup", "1. Simmer.", 4,
            List.of(new GeneratedRecipe.Ingredient("Red lentils", 300, 0, 352, 24, 60, 1)));

    @Mock(answer = Answers.RETURNS_DEEP_STUBS)
    AnthropicClient client;

    @Mock
    ObjectProvider<AnthropicClient> clientProvider;

    ClaudeRecipeGenerator generator;

    @BeforeEach
    void setUp() {
        generator = new ClaudeRecipeGenerator(clientProvider, PROPERTIES);
    }

    @Test
    void buildParams_usesTheConfiguredModelAndStructuredOutput() {
        MessageCreateParams raw = generator.buildParams(REQUEST, "7 | Red lentils | 352").rawParams();

        assertThat(raw.model().asString()).isEqualTo("claude-haiku-4-5");
        assertThat(raw.maxTokens()).isEqualTo(ClaudeRecipeGenerator.MAX_TOKENS);
        assertThat(raw.system()).isPresent();
        assertThat(raw.outputConfig()).isPresent();
        assertThat(raw.outputConfig().get().format()).isPresent();
        assertThat(raw.messages()).hasSize(1);
    }

    @Test
    void userMessage_carriesTheWizardAnswersAndTheCatalog() {
        String message = ClaudeRecipeGenerator.userMessage(REQUEST, "7 | Red lentils | 352");

        assertThat(message)
                .contains("vegetarian")
                .contains("lunch")
                .contains("between 300 and 500 kcal")
                .contains("no mushrooms")
                .contains("7 | Red lentils | 352")
                .doesNotContain("Meat or fish");
    }

    @Test
    void userMessage_namesTheMeatOrLetsTheModelChoose() {
        assertThat(ClaudeRecipeGenerator.userMessage(withMeat(MeatType.BEEF), ""))
                .contains("Meat or fish to use: beef");
        assertThat(ClaudeRecipeGenerator.userMessage(withMeat(MeatType.ANY), ""))
                .contains("Meat or fish to use: your choice");
    }

    @Test
    void userMessage_saysSoWhenTheUserHasNoFoodsYet() {
        assertThat(ClaudeRecipeGenerator.userMessage(REQUEST, ""))
                .contains("(empty — this user has no foods yet)");
    }

    @Test
    void generate_returnsTheStructuredAnswer() {
        givenResponse(StopReason.END_TURN, RECIPE);

        assertThat(generator.generate(REQUEST, "")).isEqualTo(RECIPE);
    }

    @Test
    void generate_withoutClient_throwsNotConfigured() {
        when(clientProvider.getIfAvailable()).thenReturn(null);

        assertThatThrownBy(() -> generator.generate(REQUEST, ""))
                .isInstanceOf(AiNotConfiguredException.class);
    }

    @Test
    void generate_truncatedAnswer_throwsUnavailable() {
        givenResponse(StopReason.MAX_TOKENS, null);

        assertThatThrownBy(() -> generator.generate(REQUEST, ""))
                .isInstanceOf(AiUnavailableException.class);
    }

    @Test
    void generate_timeout_throwsUnavailable() {
        when(clientProvider.getIfAvailable()).thenReturn(client);
        when(client.messages().create(any(StructuredMessageCreateParams.class)))
                .thenThrow(new AnthropicIoException("timeout"));

        assertThatThrownBy(() -> generator.generate(REQUEST, ""))
                .isInstanceOf(AiUnavailableException.class);
    }

    private static RecipeGenerationRequest withMeat(MeatType meatType) {
        return new RecipeGenerationRequest(
                DietType.MEAT, MealType.DINNER, CalorieBand.OVER_700, meatType, null);
    }

    @SuppressWarnings("unchecked")
    private void givenResponse(StopReason stopReason, GeneratedRecipe recipe) {
        when(clientProvider.getIfAvailable()).thenReturn(client);
        StructuredMessage<GeneratedRecipe> response = mock();
        when(response.stopReason()).thenReturn(Optional.of(stopReason));
        if (recipe != null) {
            StructuredTextBlock<GeneratedRecipe> text = mock();
            when(text.text()).thenReturn(recipe);
            StructuredContentBlock<GeneratedRecipe> block = mock();
            when(block.text()).thenReturn(Optional.of(text));
            when(response.content()).thenReturn(List.of(block));
        }
        when(client.messages().create(any(StructuredMessageCreateParams.class))).thenReturn(response);
    }
}

package com.lifey.nutrition.estimation.client;

import com.anthropic.client.AnthropicClient;
import com.anthropic.errors.AnthropicInvalidDataException;
import com.anthropic.errors.AnthropicIoException;
import com.anthropic.errors.RateLimitException;
import com.anthropic.models.messages.ContentBlockParam;
import com.anthropic.models.messages.MessageCreateParams;
import com.anthropic.models.messages.StopReason;
import com.anthropic.models.messages.StructuredContentBlock;
import com.anthropic.models.messages.StructuredMessage;
import com.anthropic.models.messages.StructuredMessageCreateParams;
import com.anthropic.models.messages.StructuredTextBlock;
import com.lifey.ai.AiProperties;
import com.lifey.ai.exception.AiNotConfiguredException;
import com.lifey.ai.exception.AiUnavailableException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Answers;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.beans.factory.ObjectProvider;

import java.util.Base64;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ClaudeMealPhotoAnalyzerTest {

    private static final byte[] JPEG = {(byte) 0xFF, (byte) 0xD8, 1, 2, 3};
    private static final AiProperties PROPERTIES = new AiProperties("sk-test", "claude-haiku-4-5", 60);
    private static final MealPhotoEstimate ESTIMATE = new MealPhotoEstimate(
            List.of(new MealPhotoEstimate.Item("Rice", 180, 234, 4.3, 50.8, 0.5, EstimationConfidence.HIGH)),
            "");

    @Mock(answer = Answers.RETURNS_DEEP_STUBS)
    AnthropicClient client;

    @Mock
    ObjectProvider<AnthropicClient> clientProvider;

    ClaudeMealPhotoAnalyzer analyzer;

    @BeforeEach
    void setUp() {
        analyzer = new ClaudeMealPhotoAnalyzer(clientProvider, PROPERTIES);
    }

    @Test
    void buildParams_sendsImageThenInstructionWithStructuredOutput() {
        MessageCreateParams raw = analyzer.buildParams(JPEG).rawParams();

        assertThat(raw.model().asString()).isEqualTo("claude-haiku-4-5");
        assertThat(raw.maxTokens()).isEqualTo(ClaudeMealPhotoAnalyzer.MAX_TOKENS);
        assertThat(raw.system()).isPresent();
        assertThat(raw.outputConfig()).isPresent();
        assertThat(raw.outputConfig().get().format()).isPresent();

        assertThat(raw.messages()).hasSize(1);
        List<ContentBlockParam> blocks = raw.messages().getFirst().content().asBlockParams();
        assertThat(blocks).hasSize(2);
        assertThat(blocks.get(0).isImage()).isTrue();
        assertThat(blocks.get(0).asImage().source().asBase64().data())
                .isEqualTo(Base64.getEncoder().encodeToString(JPEG));
        assertThat(blocks.get(1).asText().text()).isEqualTo(ClaudeMealPhotoAnalyzer.USER_INSTRUCTION);
    }

    @Test
    void analyze_returnsTheStructuredAnswer() {
        givenResponse(StopReason.END_TURN, ESTIMATE);

        assertThat(analyzer.analyze(JPEG)).isEqualTo(ESTIMATE);
    }

    @Test
    void analyze_usesConfiguredModel() {
        givenResponse(StopReason.END_TURN, ESTIMATE);
        @SuppressWarnings("unchecked")
        ArgumentCaptor<StructuredMessageCreateParams<MealPhotoEstimate>> captor =
                ArgumentCaptor.forClass(StructuredMessageCreateParams.class);

        analyzer.analyze(JPEG);

        org.mockito.Mockito.verify(client.messages()).create(captor.capture());
        assertThat(captor.getValue().rawParams().model().asString()).isEqualTo("claude-haiku-4-5");
    }

    @Test
    void analyze_withoutClient_throwsNotConfigured() {
        when(clientProvider.getIfAvailable()).thenReturn(null);

        assertThatThrownBy(() -> analyzer.analyze(JPEG)).isInstanceOf(AiNotConfiguredException.class);
    }

    @Test
    void analyze_refusal_throwsUnavailable() {
        givenResponse(StopReason.REFUSAL, null);

        assertThatThrownBy(() -> analyzer.analyze(JPEG)).isInstanceOf(AiUnavailableException.class);
    }

    @Test
    void analyze_truncatedAnswer_throwsUnavailable() {
        givenResponse(StopReason.MAX_TOKENS, null);

        assertThatThrownBy(() -> analyzer.analyze(JPEG)).isInstanceOf(AiUnavailableException.class);
    }

    @Test
    void analyze_answerNotMatchingSchema_throwsUnavailable() {
        StructuredTextBlock<MealPhotoEstimate> text = mock();
        when(text.text()).thenThrow(new AnthropicInvalidDataException("bad json"));
        givenBlocks(StopReason.END_TURN, text);

        assertThatThrownBy(() -> analyzer.analyze(JPEG))
                .isInstanceOf(AiUnavailableException.class)
                .hasCauseInstanceOf(AnthropicInvalidDataException.class);
    }

    @Test
    void analyze_rateLimited_throwsUnavailable() {
        when(clientProvider.getIfAvailable()).thenReturn(client);
        RateLimitException rateLimited = mock();
        when(client.messages().create(any(StructuredMessageCreateParams.class))).thenThrow(rateLimited);

        assertThatThrownBy(() -> analyzer.analyze(JPEG))
                .isInstanceOf(AiUnavailableException.class)
                .hasCause(rateLimited);
    }

    @Test
    void analyze_timeout_throwsUnavailable() {
        when(clientProvider.getIfAvailable()).thenReturn(client);
        when(client.messages().create(any(StructuredMessageCreateParams.class)))
                .thenThrow(new AnthropicIoException("timeout"));

        assertThatThrownBy(() -> analyzer.analyze(JPEG)).isInstanceOf(AiUnavailableException.class);
    }

    private void givenResponse(StopReason stopReason, MealPhotoEstimate estimate) {
        StructuredTextBlock<MealPhotoEstimate> text = mock();
        if (estimate != null) {
            when(text.text()).thenReturn(estimate);
        }
        givenBlocks(stopReason, text);
    }

    @SuppressWarnings("unchecked")
    private void givenBlocks(StopReason stopReason, StructuredTextBlock<MealPhotoEstimate> text) {
        when(clientProvider.getIfAvailable()).thenReturn(client);
        StructuredMessage<MealPhotoEstimate> response = mock();
        when(response.stopReason()).thenReturn(Optional.of(stopReason));
        if (StopReason.END_TURN.equals(stopReason)) {
            StructuredContentBlock<MealPhotoEstimate> block = mock();
            when(block.text()).thenReturn(Optional.of(text));
            when(response.content()).thenReturn(List.of(block));
        }
        when(client.messages().create(any(StructuredMessageCreateParams.class))).thenReturn(response);
    }
}

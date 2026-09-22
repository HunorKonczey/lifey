package com.lifey.nutrition.estimation.client;

import com.anthropic.client.AnthropicClient;
import com.anthropic.client.okhttp.AnthropicOkHttpClient;
import com.lifey.ai.AiProperties;
import com.lifey.common.image.ImageReencoder;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.ObjectProvider;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.List;
import java.util.stream.Stream;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * The manual smoke test docs/23-ai-calorie-estimation-plan.md asks for (step
 * 3): a real Claude API call, against real photos, costing real money. Skipped
 * unless {@code ANTHROPIC_API_KEY} is set, so CI and every other developer
 * never run it.
 *
 * <p>Point it at photos with {@code LIFEY_AI_TEST_IMAGES} (paths separated by
 * {@code ;} or {@code ,}), and pick the model with {@code LIFEY_AI_MODEL}
 * (default {@code claude-haiku-4-5}). It prints what the model returned — the
 * quality judgement is the reader's, not an assertion; only the contract
 * (schema, plausible ranges) is asserted.
 */
@EnabledIfEnvironmentVariable(named = "ANTHROPIC_API_KEY", matches = ".+")
class ClaudeMealPhotoAnalyzerLiveTest {

    private static final int MAX_SIDE = 1024;

    @Test
    void estimatesEachConfiguredPhoto() throws IOException {
        List<Path> photos = photos();
        assertThat(photos).as("set LIFEY_AI_TEST_IMAGES to one or more photo paths").isNotEmpty();

        String model = System.getenv().getOrDefault("LIFEY_AI_MODEL", "claude-haiku-4-5");
        ClaudeMealPhotoAnalyzer analyzer = analyzer(model);

        for (Path photo : photos) {
            byte[] jpeg = downscale(photo);
            long startedAt = System.currentTimeMillis();
            MealPhotoEstimate estimate = analyzer.analyze(jpeg);
            long millis = System.currentTimeMillis() - startedAt;

            System.out.printf("%n=== %s · %s · %d ms · %d KB sent%n",
                    photo.getFileName(), model, millis, jpeg.length / 1024);
            for (MealPhotoEstimate.Item item : estimate.items()) {
                System.out.printf("  %-34s %6.0f g %6.0f kcal  P %5.1f  C %5.1f  F %5.1f  [%s]%n",
                        item.name(), item.estimatedGrams(), item.calories(),
                        item.proteinGrams(), item.carbsGrams(), item.fatGrams(), item.confidence());
            }
            System.out.printf("  total: %.0f kcal · notes: %s%n",
                    estimate.items().stream().mapToDouble(MealPhotoEstimate.Item::calories).sum(),
                    estimate.notes());

            assertThat(estimate.items()).allSatisfy(item -> {
                assertThat(item.name()).isNotBlank();
                assertThat(item.estimatedGrams()).isBetween(1.0, 3000.0);
                assertThat(item.calories()).isBetween(0.0, item.estimatedGrams() * 9.5);
                assertThat(item.confidence()).isNotNull();
            });
        }
    }

    private static ClaudeMealPhotoAnalyzer analyzer(String model) {
        AiProperties properties = new AiProperties(System.getenv("ANTHROPIC_API_KEY"), model, 60);
        AnthropicClient client = AnthropicOkHttpClient.builder()
                .apiKey(properties.apiKey())
                .timeout(Duration.ofSeconds(properties.timeoutSeconds()))
                .build();
        return new ClaudeMealPhotoAnalyzer(new SingletonProvider<>(client), properties);
    }

    private static List<Path> photos() {
        String configured = System.getenv("LIFEY_AI_TEST_IMAGES");
        if (configured == null || configured.isBlank()) return List.of();
        return Stream.of(configured.split("[;,]"))
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .map(Path::of)
                .toList();
    }

    private static byte[] downscale(Path photo) throws IOException {
        try (InputStream in = Files.newInputStream(photo)) {
            return ImageReencoder.boundedJpeg(ImageReencoder.decode(in), MAX_SIDE);
        }
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

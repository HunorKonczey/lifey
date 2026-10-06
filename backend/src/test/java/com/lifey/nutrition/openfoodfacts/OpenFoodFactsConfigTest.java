package com.lifey.nutrition.openfoodfacts;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.ConfigDataApplicationContextInitializer;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.web.client.RestClient;

import static org.assertj.core.api.Assertions.assertThat;

/** The wiring of {@link OpenFoodFactsConfig} against the real application.yml — no database needed (docs/84). */
class OpenFoodFactsConfigTest {

    private final ApplicationContextRunner runner = new ApplicationContextRunner()
            .withInitializer(new ConfigDataApplicationContextInitializer())
            .withUserConfiguration(OpenFoodFactsConfig.class);

    @Test
    void bindsTheProductAndTheSearchSettingsFromApplicationYml() {
        runner.run(context -> {
            OpenFoodFactsProperties props = context.getBean(OpenFoodFactsProperties.class);
            assertThat(props.baseUrl()).isEqualTo("https://world.openfoodfacts.org");
            assertThat(props.searchBaseUrl()).isEqualTo("https://search.openfoodfacts.org");
            assertThat(props.searchPerMinute()).isEqualTo(8);
            assertThat(props.huCountryTag()).isEqualTo("en:hungary");
            assertThat(props.userAgent()).startsWith("Lifey/");
        });
    }

    @Test
    void definesOneRestClientForTheProductApiAndOneForSearch() {
        runner.run(context -> {
            assertThat(context.getBeansOfType(RestClient.class)).containsOnlyKeys("openFoodFactsRestClient", "openFoodFactsSearchRestClient");
            assertThat(context.getBean("openFoodFactsRestClient")).isNotSameAs(context.getBean("openFoodFactsSearchRestClient"));
        });
    }

    @Test
    void theSearchHostAndLimitCanBeOverriddenByEnvironment() {
        runner.withPropertyValues(
                        "OPENFOODFACTS_SEARCH_BASE_URL=http://localhost:9999",
                        "OPENFOODFACTS_SEARCH_PER_MINUTE=3")
                .run(context -> {
                    OpenFoodFactsProperties props = context.getBean(OpenFoodFactsProperties.class);
                    assertThat(props.searchBaseUrl()).isEqualTo("http://localhost:9999");
                    assertThat(props.searchPerMinute()).isEqualTo(3);
                });
    }
}

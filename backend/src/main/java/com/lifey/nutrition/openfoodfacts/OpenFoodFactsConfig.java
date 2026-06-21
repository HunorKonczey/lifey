package com.lifey.nutrition.openfoodfacts;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpHeaders;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.web.client.RestClient;

import java.time.Duration;

/**
 * Wires the {@link RestClient} used to talk to OpenFoodFacts: base URL and the
 * required {@code User-Agent} come from {@link OpenFoodFactsProperties}, with a
 * short connect/read timeout so a slow community server can never stall a
 * barcode lookup.
 */
@Configuration
@EnableConfigurationProperties(OpenFoodFactsProperties.class)
class OpenFoodFactsConfig {

    private static final Duration TIMEOUT = Duration.ofSeconds(3);

    @Bean
    RestClient openFoodFactsRestClient(OpenFoodFactsProperties properties) {
        SimpleClientHttpRequestFactory requestFactory = new SimpleClientHttpRequestFactory();
        requestFactory.setConnectTimeout(TIMEOUT);
        requestFactory.setReadTimeout(TIMEOUT);

        return RestClient.builder()
                .baseUrl(properties.baseUrl())
                .defaultHeader(HttpHeaders.USER_AGENT, properties.userAgent())
                .requestFactory(requestFactory)
                .build();
    }
}

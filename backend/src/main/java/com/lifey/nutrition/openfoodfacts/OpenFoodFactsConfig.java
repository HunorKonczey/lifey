package com.lifey.nutrition.openfoodfacts;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpHeaders;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.web.client.RestClient;

import java.time.Duration;

/**
 * Wires the {@link RestClient}s used to talk to OpenFoodFacts: base URL and the
 * required {@code User-Agent} come from {@link OpenFoodFactsProperties}, with a
 * short connect/read timeout so a slow community server can never stall a
 * lookup. The product API (barcode) and the full-text search service (name
 * search, docs/84) are different hosts, hence two clients.
 */
@Configuration
@EnableConfigurationProperties(OpenFoodFactsProperties.class)
class OpenFoodFactsConfig {

    private static final Duration TIMEOUT = Duration.ofSeconds(3);
    private static final Duration SEARCH_CONNECT_TIMEOUT = Duration.ofSeconds(2);
    private static final Duration SEARCH_READ_TIMEOUT = Duration.ofSeconds(3);

    @Bean
    RestClient openFoodFactsRestClient(OpenFoodFactsProperties properties) {
        return build(properties.baseUrl(), properties.userAgent(), TIMEOUT, TIMEOUT);
    }

    /**
     * Typical search latency is ~0.2 s (docs/84 spike); a Hungarian search that
     * finds nothing is followed by an English one, so the worst case for one user
     * request is two of these back to back.
     */
    @Bean
    RestClient openFoodFactsSearchRestClient(OpenFoodFactsProperties properties) {
        return build(properties.searchBaseUrl(), properties.userAgent(), SEARCH_CONNECT_TIMEOUT, SEARCH_READ_TIMEOUT);
    }

    private static RestClient build(String baseUrl, String userAgent, Duration connectTimeout, Duration readTimeout) {
        SimpleClientHttpRequestFactory requestFactory = new SimpleClientHttpRequestFactory();
        requestFactory.setConnectTimeout(connectTimeout);
        requestFactory.setReadTimeout(readTimeout);

        return RestClient.builder()
                .baseUrl(baseUrl)
                .defaultHeader(HttpHeaders.USER_AGENT, userAgent)
                .requestFactory(requestFactory)
                .build();
    }
}

package com.lifey.chat.spi.http;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.web.client.RestClient;

/**
 * The one HTTP client this service uses to call {@code lifey-api} (§6.1).
 *
 * <p>Bounded timeouts are not a detail here. The push send happens inside an
 * {@code AFTER_COMMIT} listener on a message that is already stored and already
 * visible over REST; if the monolith hangs, the worst acceptable outcome is a
 * missed notification, not a chat request thread parked for a minute. The §5.4
 * reminder job comes back for whatever was dropped.
 */
@Configuration
@EnableConfigurationProperties(MonolithProperties.class)
class MonolithClientConfig {

    @Bean
    RestClient monolithRestClient(MonolithProperties properties) {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(properties.connectTimeout());
        factory.setReadTimeout(properties.readTimeout());

        RestClient.Builder builder = RestClient.builder().requestFactory(factory);
        if (properties.isConfigured()) {
            builder.baseUrl(properties.baseUrl());
        }
        // The shared secret rides on every request rather than being set at each
        // call site — one place to get it right, and adding an endpoint later
        // cannot forget it (§5.5).
        if (properties.internalToken() != null && !properties.internalToken().isBlank()) {
            builder.defaultHeader(InternalHeaders.TOKEN_HEADER, properties.internalToken());
        }
        return builder.build();
    }
}

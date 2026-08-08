package com.lifey.internal;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.web.client.RestClient;

/**
 * The outbound half of the seam: how this application calls {@code lifey-chat}.
 *
 * <p>Mirrors {@code MonolithClientConfig} on the other side, including the
 * bounded timeouts — for the same reason, from the other direction.
 */
@Configuration
class ChatServiceClientConfig {

    @Bean
    RestClient chatServiceRestClient(InternalApiProperties properties) {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(properties.connectTimeout());
        factory.setReadTimeout(properties.readTimeout());

        RestClient.Builder builder = RestClient.builder().requestFactory(factory);
        if (properties.hasChatService()) {
            builder.baseUrl(properties.chatUrl());
        }
        // On every request rather than at each call site, so adding an endpoint
        // later cannot forget it.
        if (properties.isConfigured()) {
            builder.defaultHeader(InternalAuthFilter.TOKEN_HEADER, properties.token());
        }
        return builder.build();
    }
}

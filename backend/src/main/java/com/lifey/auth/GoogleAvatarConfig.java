package com.lifey.auth;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.web.client.RestClient;

import java.time.Duration;

/**
 * {@link RestClient} used only to download a Google account picture at social
 * login (see {@link GoogleAvatarImportListener}) — short timeouts so a slow or
 * unresponsive image host can never stall the async import job for long.
 */
@Configuration
class GoogleAvatarConfig {

    private static final Duration TIMEOUT = Duration.ofSeconds(5);

    @Bean
    RestClient googleAvatarRestClient() {
        SimpleClientHttpRequestFactory requestFactory = new SimpleClientHttpRequestFactory();
        requestFactory.setConnectTimeout(TIMEOUT);
        requestFactory.setReadTimeout(TIMEOUT);

        return RestClient.builder()
                .requestFactory(requestFactory)
                .build();
    }
}

package com.lifey.ai;

import com.anthropic.client.AnthropicClient;
import com.anthropic.client.okhttp.AnthropicOkHttpClient;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Conditional;
import org.springframework.context.annotation.Condition;
import org.springframework.context.annotation.ConditionContext;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.type.AnnotatedTypeMetadata;

import java.time.Duration;

/**
 * Builds the Anthropic SDK client — only when an API key is configured. The
 * SDK resolves credentials from the environment and on-disk profiles when it
 * is given none, which is not something a server should do silently; without a
 * key there is simply no client bean, and callers answer 503 instead.
 */
@Configuration
@EnableConfigurationProperties(AiProperties.class)
class AiClientConfig {

    @Bean
    @Conditional(ApiKeyConfigured.class)
    AnthropicClient anthropicClient(AiProperties properties) {
        return AnthropicOkHttpClient.builder()
                .apiKey(properties.apiKey())
                .timeout(Duration.ofSeconds(properties.timeoutSeconds()))
                .build();
    }

    static class ApiKeyConfigured implements Condition {

        @Override
        public boolean matches(ConditionContext context, AnnotatedTypeMetadata metadata) {
            String apiKey = context.getEnvironment().getProperty("lifey.ai.api-key");
            return apiKey != null && !apiKey.isBlank();
        }
    }
}

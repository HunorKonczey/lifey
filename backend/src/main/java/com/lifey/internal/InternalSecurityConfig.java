package com.lifey.internal;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;

/**
 * A separate filter chain for {@code /internal/**}, ahead of the main one
 * (docs/chat/44-chat-service-extraction-plan.md §5.5).
 *
 * <p>Separate rather than another rule inside {@code SecurityConfig} because
 * these requests carry no user token at all: running them through the JWT
 * filter, the entry point and the access-denied handler would mean reasoning
 * about two authentication schemes in one chain every time either changes.
 *
 * <p><b>No {@code /api/v1} prefix</b> on these paths, deliberately: a reverse
 * proxy rule written for {@code /api/**} cannot accidentally expose them, and
 * springdoc does not advertise them next to the public API.
 */
@Configuration
@EnableConfigurationProperties(InternalApiProperties.class)
class InternalSecurityConfig {

    @Bean
    @Order(Ordered.HIGHEST_PRECEDENCE)
    @SuppressWarnings("java:S4502") // reviewed: no cookies, no session — see below
    SecurityFilterChain internalFilterChain(HttpSecurity http,
                                            InternalApiProperties properties,
                                            ObjectMapper objectMapper) {
        http
                .securityMatcher("/internal/**")
                // No CORS: browsers have no business calling these. Omitting the
                // config means no Access-Control-Allow-Origin header, so a
                // cross-origin call fails in the browser before it starts.
                .csrf(AbstractHttpConfigurer::disable)
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                // The filter below is the whole authorization decision; Spring
                // Security is not asked to check anything else.
                .authorizeHttpRequests(auth -> auth.anyRequest().permitAll())
                .addFilterBefore(new InternalAuthFilter(properties, objectMapper),
                        org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }
}

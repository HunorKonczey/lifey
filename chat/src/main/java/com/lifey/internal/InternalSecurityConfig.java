package com.lifey.internal;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.lifey.chat.spi.http.MonolithProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

/**
 * A separate filter chain for {@code /internal/**}, ahead of the JWT one
 * (docs/chat/44-chat-service-extraction-plan.md §5.5).
 *
 * <p>Separate rather than another rule in {@code SecurityConfig} because these
 * requests carry no user token at all — running them through the JWT filter and
 * its entry point would mean two authentication schemes tangled in one chain.
 *
 * <p>The secret is read from {@code lifey.monolith.internal-token}: the same
 * value this service <em>sends</em> when it calls the monolith. One secret for
 * the seam, in both directions, so there is one thing to rotate.
 */
@Configuration
class InternalSecurityConfig {

    @Bean
    @Order(Ordered.HIGHEST_PRECEDENCE)
    @SuppressWarnings("java:S4502") // reviewed: no cookies, no session
    SecurityFilterChain internalFilterChain(HttpSecurity http,
                                            MonolithProperties properties,
                                            ObjectMapper objectMapper) {
        http
                .securityMatcher("/internal/**")
                // No CORS: browsers have no business here, and omitting the
                // config means a cross-origin call fails before it starts.
                .csrf(AbstractHttpConfigurer::disable)
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth.anyRequest().permitAll())
                .addFilterBefore(new InternalAuthFilter(properties.internalToken(), objectMapper),
                        UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }
}

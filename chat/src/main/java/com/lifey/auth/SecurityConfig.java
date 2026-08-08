package com.lifey.auth;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfigurationSource;

/**
 * Stateless, JWT-based security. Same shape as {@code lifey-api}'s, minus
 * everything this service cannot do: there are no public auth endpoints here
 * because there is no auth here — {@code lifey-api} issues and refreshes
 * tokens, this service only verifies them (§5.3).
 *
 * <p>The surface is therefore tiny: {@code /api/v1/chat/**} for authenticated
 * callers, {@code /actuator/health} for the Render deploy probe, and the rest of
 * actuator behind {@code ROLE_SUPER_ADMIN} — the chat metrics are the reason
 * that endpoint exists at all (plan §21).
 */
@Configuration
public class SecurityConfig {

    private static final String[] PUBLIC_ENDPOINTS = {
            "/swagger-ui.html",
            "/swagger-ui/**",
            "/v3/api-docs/**",
            "/actuator/health",
            "/actuator/health/**"
    };

    /**
     * Boot 4's auto-configured mapper is a Jackson 3 {@code tools.jackson}
     * {@code JsonMapper}, not the Jackson 2 type this codebase uses (jjwt,
     * {@code ApiError}) — so there's no compatible bean to inject into the
     * entry point and the access-denied handler. JavaTimeModule is registered
     * explicitly since this mapper isn't Boot-managed; without it, serializing
     * {@code ApiError.timestamp} fails.
     */
    @Bean
    public ObjectMapper objectMapper() {
        return new ObjectMapper().registerModule(new JavaTimeModule());
    }

    @Bean
    @SuppressWarnings("java:S4502") // reviewed: see the .csrf(...) comment below
    public SecurityFilterChain filterChain(HttpSecurity http,
                                           JwtVerifier jwtVerifier,
                                           JwtAuthenticationEntryPoint entryPoint,
                                           JwtAccessDeniedHandler accessDeniedHandler,
                                           CorsConfigurationSource corsConfigurationSource) {
        http
                .cors(cors -> cors.configurationSource(corsConfigurationSource))
                // Safe: auth is a bearer token in the Authorization header (see
                // JwtAuthenticationFilter), never a cookie — nothing here rides
                // along automatically on a cross-site request for CSRF to forge.
                .csrf(AbstractHttpConfigurer::disable)
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers(PUBLIC_ENDPOINTS).permitAll()
                        // /actuator/health stays public above (the deploy probe
                        // needs it); everything else actuator exposes is
                        // operational detail — here, the chat counters and the
                        // stream-connection gauge that the scaling decision is
                        // read from (devops/chat-operations.md).
                        .requestMatchers("/actuator/**").hasRole("SUPER_ADMIN")
                        // Chat access is never decided by role: a caller is
                        // authorized for a thread iff they are one of its two
                        // participants, which the service layer checks (§4).
                        .anyRequest().authenticated())
                .exceptionHandling(handling -> handling
                        .authenticationEntryPoint(entryPoint)
                        .accessDeniedHandler(accessDeniedHandler))
                // Not a bean (see JwtAuthenticationFilter's Javadoc) — constructed
                // directly so Spring Boot doesn't also auto-register it globally.
                .addFilterBefore(new JwtAuthenticationFilter(jwtVerifier),
                        UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }
}

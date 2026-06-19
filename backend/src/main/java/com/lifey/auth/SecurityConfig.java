package com.lifey.auth;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

/**
 * Stateless, JWT-based security: no sessions, no CSRF (there's no cookie-based
 * session to forge), every {@code /api/**} route requires a valid access token
 * except the handful of public auth endpoints and the API docs.
 */
@Configuration
@EnableConfigurationProperties(JwtProperties.class)
public class SecurityConfig {

    private static final String[] PUBLIC_ENDPOINTS = {
            "/api/v1/auth/register",
            "/api/v1/auth/login",
            "/api/v1/auth/refresh",
            "/swagger-ui.html",
            "/swagger-ui/**",
            "/v3/api-docs/**"
    };

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    /**
     * Spring Boot wires this from the {@code UserDetailsService} + {@code PasswordEncoder}
     * beans already in context ({@link CustomUserDetailsService} and the encoder above) —
     * no manual {@code DaoAuthenticationProvider} needed.
     */
    @Bean
    public AuthenticationManager authenticationManager(AuthenticationConfiguration configuration) {
        return configuration.getAuthenticationManager();
    }

    /**
     * Spring Boot 4's auto-configured mapper is a Jackson 3 {@code tools.jackson}
     * {@code JsonMapper}, not the Jackson 2 {@code com.fasterxml.jackson} type this
     * codebase uses (jjwt, {@link com.lifey.common.exception.ApiError}) — so there's
     * no compatible bean to inject here. JavaTimeModule is registered explicitly
     * since this mapper isn't Boot-managed and won't get it automatically; without
     * it, serializing an {@code Instant} (e.g. in {@code ApiError.timestamp}) fails.
     */
    @Bean
    public ObjectMapper objectMapper() {
        return new ObjectMapper().registerModule(new JavaTimeModule());
    }

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http,
                                           JwtService jwtService,
                                           JwtAuthenticationEntryPoint entryPoint,
                                           JwtAccessDeniedHandler accessDeniedHandler) {
        http
                .csrf(AbstractHttpConfigurer::disable)
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers(PUBLIC_ENDPOINTS).permitAll()
                        .anyRequest().authenticated())
                .exceptionHandling(handling -> handling
                        .authenticationEntryPoint(entryPoint)
                        .accessDeniedHandler(accessDeniedHandler))
                // Not a bean (see JwtAuthenticationFilter's Javadoc) — constructed
                // directly so Spring Boot doesn't also auto-register it globally.
                .addFilterBefore(new JwtAuthenticationFilter(jwtService), UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }
}

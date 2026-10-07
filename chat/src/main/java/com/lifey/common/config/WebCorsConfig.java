package com.lifey.common.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.Arrays;
import java.util.List;

/**
 * Single CORS source used by both Spring MVC and Spring Security.
 * Explicit allowed origins are required when allowCredentials=true
 * (wildcard "*" is rejected by the CORS spec in that case).
 */
@Configuration
public class WebCorsConfig {

    @Value("${lifey.cors.allowed-origins}")
    private String allowedOriginsRaw;

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        List<String> origins = parseOrigins(allowedOriginsRaw);

        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOrigins(origins);
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of("*"));
        config.setAllowCredentials(true);
        config.setMaxAge(3600L);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/api/**", config);
        return source;
    }

    /**
     * The comma-separated origin list as the browser will send each one: trimmed (a space after the
     * comma in the environment variable would otherwise make that origin silently never match), without
     * a trailing slash (an `Origin` header never has one) and without empty entries.
     */
    static List<String> parseOrigins(String raw) {
        return Arrays.stream(raw.split(","))
                .map(String::trim)
                .map(origin -> origin.endsWith("/") ? origin.substring(0, origin.length() - 1) : origin)
                .filter(origin -> !origin.isEmpty())
                .toList();
    }
}

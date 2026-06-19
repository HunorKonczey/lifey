package com.lifey.common.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * Permissive CORS for local development so a Flutter web/Safari build (served on a
 * different origin) can call the API. Tighten the allowed origins before production.
 */
@Configuration
public class WebCorsConfig implements WebMvcConfigurer {

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/api/**")
                .allowedOriginPatterns("*")
                .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
                // Explicit so the `Authorization: Bearer <token>` header always survives
                // CORS preflight, regardless of Spring's default-header behavior.
                .allowedHeaders("*");
    }
}

package com.lifey.common.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.info.License;
import io.swagger.v3.oas.models.servers.Server;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * OpenAPI / Swagger UI configuration. The interactive docs are served at
 * {@code /swagger-ui.html} and the raw spec at {@code /v3/api-docs}.
 */
@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI lifeyOpenAPI() {
        return new OpenAPI()
                .info(new Info()
                        .title("Lifey API")
                        .description("""
                                REST API for the Lifey fitness & nutrition tracker. \
                                Track foods, recipes, meals, workouts, body weight, and view aggregated statistics.""")
                        .version("v1")
                        .license(new License().name("Proprietary")))
                .addServersItem(new Server()
                        .url("http://localhost:8080")
                        .description("Local development"));
    }
}

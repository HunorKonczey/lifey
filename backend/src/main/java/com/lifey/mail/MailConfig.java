package com.lifey.mail;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.task.TaskExecutor;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

/**
 * Small dedicated pool for {@code @Async} mail sends, kept separate from
 * Spring's default (shared, unbounded-queue) executor so a burst of emails
 * can never starve other {@code @Async} work in the app.
 */
@Configuration
@EnableAsync
@EnableConfigurationProperties(MailProperties.class)
class MailConfig {

    @Bean
    TaskExecutor mailTaskExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(1);
        executor.setMaxPoolSize(2);
        executor.setQueueCapacity(50);
        executor.setThreadNamePrefix("mail-");
        executor.initialize();
        return executor;
    }
}

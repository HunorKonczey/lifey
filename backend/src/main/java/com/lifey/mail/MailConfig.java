package com.lifey.mail;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.MessageSource;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.support.ResourceBundleMessageSource;
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
public class MailConfig {

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

    /**
     * Named (not "messageSource") so this doesn't collide with the default
     * bean Spring Boot auto-configures from {@code classpath:messages} — mail
     * wording lives under its own basename ({@code i18n/mail_*.properties}).
     * {@code useCodeAsDefaultMessage(false)} means a missing key throws rather
     * than silently leaking the raw key into a sent email.
     */
    @Bean
    MessageSource mailMessageSource() {
        ResourceBundleMessageSource messageSource = new ResourceBundleMessageSource();
        messageSource.setBasename("i18n/mail");
        messageSource.setDefaultEncoding("UTF-8");
        messageSource.setUseCodeAsDefaultMessage(false);
        messageSource.setFallbackToSystemLocale(false);
        return messageSource;
    }
}

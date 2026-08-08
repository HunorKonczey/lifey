package com.lifey.push;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.task.TaskExecutor;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

/**
 * Small dedicated pool for {@code @Async} push sends, kept separate from
 * Spring's default executor for the same reason as {@code mailTaskExecutor}
 * (see {@code MailConfig}) — a burst of pushes shouldn't starve other
 * {@code @Async} work.
 */
@Configuration
@EnableAsync
@EnableConfigurationProperties(PushProperties.class)
public class PushConfig {

    @Bean
    TaskExecutor pushTaskExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(1);
        executor.setMaxPoolSize(4);
        executor.setQueueCapacity(200);
        executor.setThreadNamePrefix("push-");
        executor.initialize();
        return executor;
    }
}

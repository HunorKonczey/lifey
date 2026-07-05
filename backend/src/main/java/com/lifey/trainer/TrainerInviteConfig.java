package com.lifey.trainer;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;

@Configuration
@EnableConfigurationProperties(TrainerInviteProperties.class)
class TrainerInviteConfig {
}

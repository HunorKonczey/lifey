package com.lifey.nutrition.food.backfill;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;

@Configuration
@EnableConfigurationProperties(FoodFiberSugarBackfillProperties.class)
class FoodBackfillConfig {
}

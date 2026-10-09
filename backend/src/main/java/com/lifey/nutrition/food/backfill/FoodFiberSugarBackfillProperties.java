package com.lifey.nutrition.food.backfill;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.time.Duration;

/**
 * Bound from {@code lifey.backfill.food-fiber-sugar.*} (application.yml; switched on in application-prod.yml).
 *
 * @param enabled                 whether the job runs at all - off by default, so tests and a developer's machine never call
 *                                OpenFoodFacts on their own
 * @param batchSize               foods read from the database per round
 * @param delay                   the pause after every OpenFoodFacts call; OFF allows about 100 product reads a minute per
 *                                client, 700 ms is about 85
 * @param attempts                tries per food before it is given up on for this run
 * @param maxConsecutiveFailures  foods in a row that could not be looked up before the run stops (OFF is down) and tries again
 *                                at the next tick, from where it left off
 * @param lease                   how long a run holds the job; a crashed run's lease runs out and another takes over
 * @param initialDelay            the wait after start-up before the first run
 * @param retryEvery              the pause between runs, until one finishes the whole job
 */
@ConfigurationProperties(prefix = "lifey.backfill.food-fiber-sugar")
public record FoodFiberSugarBackfillProperties(
        boolean enabled,
        int batchSize,
        Duration delay,
        int attempts,
        int maxConsecutiveFailures,
        Duration lease,
        Duration initialDelay,
        Duration retryEvery
) {
}

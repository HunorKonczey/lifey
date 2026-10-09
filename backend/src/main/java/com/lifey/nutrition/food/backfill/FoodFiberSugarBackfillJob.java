package com.lifey.nutrition.food.backfill;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Starts {@link FoodFiberSugarBackfillService} a minute after boot and then every {@code retry-every} until it reports the job
 * done - after which each tick is one cheap lookup of a completed row. Only exists where
 * {@code lifey.backfill.food-fiber-sugar.enabled=true} (production), so the first deploy runs it with no manual step.
 */
@Component
@ConditionalOnProperty(prefix = "lifey.backfill.food-fiber-sugar", name = "enabled", havingValue = "true")
@RequiredArgsConstructor
@Slf4j
class FoodFiberSugarBackfillJob {

    private final FoodFiberSugarBackfillService service;

    @Scheduled(initialDelayString = "${lifey.backfill.food-fiber-sugar.initial-delay}",
            fixedDelayString = "${lifey.backfill.food-fiber-sugar.retry-every}")
    void run() {
        try {
            service.runOnce();
        } catch (RuntimeException e) {
            // A scheduled task that throws is only logged by Spring and the next tick still happens; saying it here keeps the
            // cause next to the job's other lines.
            log.error("Food fibre/sugar backfill failed; it will be retried", e);
        }
    }
}

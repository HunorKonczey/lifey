package com.lifey.nutrition.food.backfill;

import com.lifey.common.job.OneTimeJob;
import com.lifey.common.job.OneTimeJobRepository;
import com.lifey.nutrition.food.Food;
import com.lifey.nutrition.food.FoodRepository;
import com.lifey.nutrition.openfoodfacts.OffProduct;
import com.lifey.nutrition.openfoodfacts.client.OpenFoodFactsClient;
import com.lifey.nutrition.openfoodfacts.exception.OffRateLimitedException;
import com.lifey.nutrition.openfoodfacts.exception.OffUnavailableException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;

import java.time.Clock;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * The one-time backfill of fibre and sugar (LIF-149): the foods saved before V89 have none, so for every live food that has a
 * barcode and lacks either figure, this asks OpenFoodFacts by that barcode and fills what is missing - and only that, so a figure
 * somebody set is never overwritten and the other macros are never touched.
 *
 * <p>It is built to be started carelessly: from a scheduler on every instance, again after a crash, in the middle of a deploy.
 * The {@code one_time_jobs} row is claimed with a lease (one runner at a time), progress is saved as a cursor over food ids (a
 * rerun continues, it does not start over), and once the whole table has been walked the row is completed and every later call
 * returns at once. Nothing here is {@code @Transactional}: there is an HTTP call per food, and each write commits on its own
 * ({@link FoodBackfillWriter}).
 *
 * <p>OpenFoodFacts is a community service with a rate limit: a pause after every call keeps well under it, a 429 stops the run
 * (it resumes at the next tick, from the same food), and a run that cannot reach OFF several foods in a row stops instead of
 * giving up on all of them. A food that fails every attempt while OFF otherwise answers is skipped and logged.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class FoodFiberSugarBackfillService {

    public static final String JOB_NAME = "food-fiber-sugar-backfill";

    /** OFF fibre and sugars are grams per 100 g; anything outside 0-100 is a data-entry error there, not a figure. */
    private static final double MAX_GRAMS_PER_100G = 100;

    private final OneTimeJobRepository jobs;
    private final FoodRepository foods;
    private final FoodBackfillWriter writer;
    private final OpenFoodFactsClient openFoodFacts;
    private final FoodFiberSugarBackfillProperties properties;
    private final Clock clock;

    /** How a run ended. */
    public enum Outcome {
        /** The whole table has been walked; the job is over for good. */
        COMPLETED,
        /** Stopped early (OpenFoodFacts rate-limited or down); the next run continues from where this one stopped. */
        INTERRUPTED,
        /** Nothing to do here: the job is already complete, or another instance holds it. */
        NOT_RUN
    }

    /** How many answers a run remembers: a popular product sits in many users' foods and is asked for once. */
    private static final int CACHE_SIZE = 2000;

    private enum Lookup { FILLED, NO_DATA, FAILED, RATE_LIMITED }

    public Outcome runOnce() {
        OneTimeJob existing = jobs.findById(JOB_NAME).orElse(null);
        if (existing == null || existing.isCompleted()) {
            return Outcome.NOT_RUN;
        }
        Instant now = clock.instant();
        if (jobs.claim(JOB_NAME, now, now.plus(properties.lease())) == 0) {
            log.debug("Food fibre/sugar backfill: held by another run, skipping");
            return Outcome.NOT_RUN;
        }

        long committed = jobs.findById(JOB_NAME).map(OneTimeJob::getCursorId).orElse(0L);
        log.info("Food fibre/sugar backfill: starting after food id {}", committed);

        // Per run, not shared: a run is the unit that holds the job, and a restart simply asks again.
        Map<String, Optional<OffProduct>> answers = new LinkedHashMap<>(16, 0.75f, true) {
            @Override
            protected boolean removeEldestEntry(Map.Entry<String, Optional<OffProduct>> eldest) {
                return size() > CACHE_SIZE;
            }
        };
        long fetchFrom = committed;
        int processed = 0;
        int filledFoods = 0;
        int noData = 0;
        int skipped = 0;
        int streak = 0;
        // What was counted since the cursor was last saved: a skipped food is only final once a later one succeeds.
        int unsavedProcessed = 0;
        int unsavedFilled = 0;

        while (true) {
            List<Food> batch = foods.findBackfillBatch(fetchFrom, PageRequest.of(0, properties.batchSize()));
            if (batch.isEmpty()) {
                jobs.saveProgress(JOB_NAME, committed, unsavedProcessed, unsavedFilled, null);
                jobs.complete(JOB_NAME, clock.instant());
                log.info("Food fibre/sugar backfill: done. {} looked up, {} foods filled, {} without data on OpenFoodFacts, {} skipped",
                        processed, filledFoods, noData, skipped);
                return Outcome.COMPLETED;
            }
            for (Food food : batch) {
                fetchFrom = food.getId();
                Lookup result = lookUp(food, answers);
                if (result == Lookup.RATE_LIMITED) {
                    return interrupted(committed, unsavedProcessed, unsavedFilled, "OpenFoodFacts rate-limited the backfill");
                }
                processed++;
                unsavedProcessed++;
                if (result == Lookup.FAILED) {
                    skipped++;
                    streak++;
                    if (streak >= properties.maxConsecutiveFailures()) {
                        // The cursor stays before the streak, so these foods are tried again.
                        return interrupted(committed, unsavedProcessed - streak, unsavedFilled,
                                "OpenFoodFacts did not answer " + streak + " foods in a row");
                    }
                    continue;
                }
                streak = 0;
                committed = food.getId();
                if (result == Lookup.FILLED) {
                    filledFoods++;
                    unsavedFilled++;
                } else {
                    noData++;
                }
            }
            jobs.saveProgress(JOB_NAME, committed, unsavedProcessed, unsavedFilled, clock.instant().plus(properties.lease()));
            unsavedProcessed = 0;
            unsavedFilled = 0;
        }
    }

    private Outcome interrupted(long committed, int processed, int filled, String reason) {
        jobs.saveProgress(JOB_NAME, committed, Math.max(processed, 0), filled, null);
        log.warn("Food fibre/sugar backfill: stopped after food id {} - {}; the next run continues from there", committed, reason);
        return Outcome.INTERRUPTED;
    }

    private Lookup lookUp(Food food, Map<String, Optional<OffProduct>> answers) {
        String barcode = food.getBarcode().trim();
        Optional<OffProduct> known = answers.get(barcode);
        if (known != null) {
            return known.map(p -> fill(food, p)).orElse(Lookup.NO_DATA);
        }
        for (int attempt = 1; attempt <= Math.max(properties.attempts(), 1); attempt++) {
            try {
                Optional<OffProduct> product = openFoodFacts.findByBarcode(barcode);
                answers.put(barcode, product);
                pause();
                return product.map(p -> fill(food, p)).orElse(Lookup.NO_DATA);
            } catch (OffRateLimitedException e) {
                return Lookup.RATE_LIMITED;
            } catch (OffUnavailableException e) {
                log.debug("Food fibre/sugar backfill: OpenFoodFacts failed for food {} (attempt {})", food.getId(), attempt, e);
                pause();
            }
        }
        log.warn("Food fibre/sugar backfill: food {} skipped, OpenFoodFacts did not answer after {} attempts", food.getId(), properties.attempts());
        return Lookup.FAILED;
    }

    private Lookup fill(Food food, OffProduct product) {
        Double fiber = plausibleOrNull(product.fiberPer100g());
        Double sugar = plausibleOrNull(product.sugarPer100g());
        if (fiber == null && sugar == null) {
            return Lookup.NO_DATA;
        }
        return writer.fill(food.getId(), fiber, sugar) > 0 ? Lookup.FILLED : Lookup.NO_DATA;
    }

    private static Double plausibleOrNull(Double grams) {
        return grams != null && grams >= 0 && grams <= MAX_GRAMS_PER_100G ? grams : null;
    }

    private void pause() {
        long millis = properties.delay().toMillis();
        if (millis <= 0) {
            return;
        }
        try {
            Thread.sleep(millis);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}

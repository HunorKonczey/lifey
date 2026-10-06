package com.lifey.nutrition.food.service;

import com.lifey.nutrition.openfoodfacts.OpenFoodFactsProperties;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import java.time.Clock;
import java.time.Duration;
import java.util.ArrayDeque;
import java.util.Deque;

/**
 * One app-wide cap on calls to OpenFoodFacts search service (docs/84 D7). Every Lifey user reaches OFF from one
 * address, and OFF documents 10 searches per minute per IP and bans for more — a ban would also take the barcode
 * scanner down — so the cap is ours, below that, and a search over it is answered {@code RATE_LIMITED} without
 * calling OFF at all.
 *
 * <p>A sliding window: a permit is the time of a call, and a call stops counting 60 seconds later. The size is
 * {@code lifey.openfoodfacts.search-per-minute} (8); {@code 0} or less allows nothing, which doubles as an off
 * switch. Only a real OFF call takes a permit — cache hits do not — and a Hungarian search that falls back to
 * English takes two. Thread-safe; per-user fairness is a non-goal (the shared address is the scarce thing).
 */
@Component
class OffSearchLimiter {

    private static final Duration WINDOW = Duration.ofMinutes(1);

    private final Clock clock;
    private final int perMinute;
    private final Deque<Long> calls = new ArrayDeque<>();

    @Autowired
    OffSearchLimiter(OpenFoodFactsProperties properties, Clock clock) {
        this(properties.searchPerMinute(), clock);
    }

    OffSearchLimiter(int perMinute, Clock clock) {
        this.perMinute = perMinute;
        this.clock = clock;
    }

    /** @return {@code true}, and counts a call, if one is still allowed in the last minute; {@code false} otherwise */
    synchronized boolean tryAcquire() {
        long now = clock.millis();
        long windowStart = now - WINDOW.toMillis();
        while (!calls.isEmpty() && calls.peekFirst() <= windowStart) {
            calls.pollFirst();
        }
        if (calls.size() >= perMinute) {
            return false;
        }
        calls.addLast(now);
        return true;
    }

    int perMinute() {
        return perMinute;
    }
}

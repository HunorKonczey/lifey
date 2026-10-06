package com.lifey.nutrition.food.service;

import com.lifey.nutrition.food.dto.OffSearchItem;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * A small bounded LRU cache with a time-to-live for OpenFoodFacts name-search results (docs/84 D7) — a few dozen
 * lines instead of Spring Cache + Caffeine, which would be a new dependency for this one cache.
 *
 * <p>What is stored is the <b>quality-filtered pass result</b> (D6), before the user's own foods are dropped:
 * that is the same for every user, while ownership is not. Keys are {@code <lang>|<sanitised text>}
 * ({@link FoodNameSearchServiceImpl}); the language is part of the key so a Hungarian answer can never serve an
 * English request. The Hungary restriction is a function of the language, so it is implied by the key — if it
 * ever becomes configurable per user it must join the key.
 *
 * <p>An empty result is a real answer and is cached (a repeated "sütőtök" should not call OFF again); failures
 * never reach this class. Cached lists are immutable copies. Thread-safe; a server restart empties it.
 */
@Component
class OffSearchCache {

    static final int DEFAULT_MAX_ENTRIES = 500;
    static final Duration DEFAULT_TTL = Duration.ofMinutes(10);

    private record Cached(List<OffSearchItem> items, Instant expiresAt) {
    }

    private final Clock clock;
    private final Duration ttl;
    private final Map<String, Cached> entries;

    @Autowired
    OffSearchCache(Clock clock) {
        this(clock, DEFAULT_MAX_ENTRIES, DEFAULT_TTL);
    }

    OffSearchCache(Clock clock, int maxEntries, Duration ttl) {
        this.clock = clock;
        this.ttl = ttl;
        // Access order: a hit moves the entry to the young end, so the eldest is the least recently used.
        this.entries = new LinkedHashMap<>(16, 0.75f, true) {
            @Override
            protected boolean removeEldestEntry(Map.Entry<String, Cached> eldest) {
                return size() > maxEntries;
            }
        };
    }

    synchronized Optional<List<OffSearchItem>> get(String key) {
        Cached entry = entries.get(key);
        if (entry == null) {
            return Optional.empty();
        }
        if (!clock.instant().isBefore(entry.expiresAt())) {
            entries.remove(key);
            return Optional.empty();
        }
        return Optional.of(entry.items());
    }

    synchronized void put(String key, List<OffSearchItem> items) {
        entries.put(key, new Cached(List.copyOf(items), clock.instant().plus(ttl)));
    }
}

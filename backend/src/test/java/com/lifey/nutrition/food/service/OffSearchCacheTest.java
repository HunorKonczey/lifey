package com.lifey.nutrition.food.service;

import com.lifey.nutrition.food.dto.OffSearchItem;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.time.Duration;
import java.util.ArrayList;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class OffSearchCacheTest {

    private MutableClock clock;
    private OffSearchCache cache;

    @BeforeEach
    void setUp() {
        clock = new MutableClock();
        cache = new OffSearchCache(clock, 2, Duration.ofMinutes(10));
    }

    private static List<OffSearchItem> items(String barcode) {
        return List.of(new OffSearchItem(barcode, "Name " + barcode, null, 100.0, 10.0, null, null));
    }

    @Test
    void aMissIsEmptyAndAHitIsTheStoredList() {
        assertThat(cache.get("hu|tej")).isEmpty();

        cache.put("hu|tej", items("1"));

        assertThat(cache.get("hu|tej")).contains(items("1"));
    }

    @Test
    void theLanguageIsPartOfTheKey_sameTextInTwoLanguagesAreTwoEntries() {
        cache.put("hu|pasta", items("hu-answer"));
        cache.put("en|pasta", items("en-answer"));

        assertThat(cache.get("hu|pasta").orElseThrow()).extracting(OffSearchItem::barcode).containsExactly("hu-answer");
        assertThat(cache.get("en|pasta").orElseThrow()).extracting(OffSearchItem::barcode).containsExactly("en-answer");
    }

    @Test
    void anEmptyResultIsAnAnswerToo() {
        cache.put("hu|sütőtök", List.of());

        assertThat(cache.get("hu|sütőtök")).isPresent();
        assertThat(cache.get("hu|sütőtök").orElseThrow()).isEmpty();
    }

    @Test
    void anEntryExpiresAfterTheTtl_notBefore() {
        cache.put("hu|tej", items("1"));

        clock.advance(Duration.ofMinutes(10).minusMillis(1));
        assertThat(cache.get("hu|tej")).isPresent();

        clock.advance(Duration.ofMillis(1));
        assertThat(cache.get("hu|tej")).isEmpty();
    }

    @Test
    void anExpiredEntryCanBeReplaced() {
        cache.put("hu|tej", items("old"));
        clock.advance(Duration.ofMinutes(11));
        assertThat(cache.get("hu|tej")).isEmpty();

        cache.put("hu|tej", items("new"));

        assertThat(cache.get("hu|tej").orElseThrow()).extracting(OffSearchItem::barcode).containsExactly("new");
    }

    @Test
    void theLeastRecentlyUsedEntryIsEvictedWhenFull() {
        cache.put("a", items("a"));
        cache.put("b", items("b"));
        cache.get("a"); // a is now the most recently used
        cache.put("c", items("c")); // over the limit of 2: b goes

        assertThat(cache.get("b")).isEmpty();
        assertThat(cache.get("a")).isPresent();
        assertThat(cache.get("c")).isPresent();
    }

    @Test
    void theStoredListIsACopy_changingTheOriginalDoesNotChangeTheCache() {
        List<OffSearchItem> original = new ArrayList<>(items("1"));
        cache.put("k", original);
        original.clear();

        assertThat(cache.get("k").orElseThrow()).hasSize(1);
    }

    @Test
    void theReturnedListCanNotBeModified() {
        cache.put("k", items("1"));
        List<OffSearchItem> got = cache.get("k").orElseThrow();

        assertThatThrownBy(() -> got.add(items("2").get(0))).isInstanceOf(UnsupportedOperationException.class);
    }
}

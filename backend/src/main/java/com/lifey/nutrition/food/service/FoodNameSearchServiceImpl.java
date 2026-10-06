package com.lifey.nutrition.food.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.nutrition.food.FoodRepository;
import com.lifey.nutrition.food.dto.OffSearchItem;
import com.lifey.nutrition.food.dto.OffSearchResponse;
import com.lifey.nutrition.food.dto.OffSearchStatus;
import com.lifey.nutrition.openfoodfacts.OffSearchHit;
import com.lifey.nutrition.openfoodfacts.OffSearchQuery;
import com.lifey.nutrition.openfoodfacts.OpenFoodFactsProperties;
import com.lifey.nutrition.openfoodfacts.client.OpenFoodFactsClient;
import com.lifey.nutrition.openfoodfacts.exception.OffRateLimitedException;
import com.lifey.nutrition.openfoodfacts.exception.OffUnavailableException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

/**
 * docs/84 D4 + D6 + D7. Deliberately <b>not</b> {@code @Transactional}: the OpenFoodFacts calls can
 * take seconds and must not hold a database connection; the one repository call is its own
 * short read-only transaction. Each OFF call goes through {@link OffSearchCache} (per-pass, user-independent
 * results) and {@link OffSearchLimiter} (the app-wide cap).
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class FoodNameSearchServiceImpl implements FoodNameSearchService {

    static final int RESULT_LIMIT = 20;

    /** Community data has typos ("9 000 kcal"): nothing real is above 900 kcal or 100 g per 100 g. */
    static final double MAX_KCAL_PER_100G = 900;
    static final double MAX_GRAMS_PER_100G = 100;

    private final OpenFoodFactsClient openFoodFactsClient;
    private final OpenFoodFactsProperties properties;
    private final FoodRepository foodRepository;
    private final CurrentUserProvider currentUserProvider;
    private final OffSearchCache cache;
    private final OffSearchLimiter limiter;

    @Override
    public OffSearchResponse search(String query, String lang) {
        String language = "hu".equalsIgnoreCase(lang == null ? null : lang.trim()) ? "hu" : "en";
        try {
            List<OffSearchItem> usable = searchPass(query, language, "hu".equals(language) ? properties.huCountryTag() : null);
            if (!usable.isEmpty()) {
                return ok(language, false, withoutOwned(usable));
            }
            if ("en".equals(language)) {
                return ok("en", false, List.of());
            }

            // Nothing usable in Hungarian, and the call itself succeeded: the English pass, with no
            // country restriction (docs/84 D4). A failed Hungarian call never gets here.
            List<OffSearchItem> english = searchPass(query, "en", null);
            if (english.isEmpty()) {
                return ok(language, false, List.of());
            }
            return ok("en", true, withoutOwned(english));
        } catch (OffRateLimitedException e) {
            log.warn("OpenFoodFacts name search rate-limited: {}", e.getMessage());
            return failed(OffSearchStatus.RATE_LIMITED, language);
        } catch (OffUnavailableException e) {
            log.warn("OpenFoodFacts name search unavailable: {}", e.getMessage());
            return failed(OffSearchStatus.UNAVAILABLE, language);
        }
    }

    /**
     * One search pass, quality-filtered and de-duplicated by barcode, in OFF order; may be empty. Served from the
     * cache when it can be (no OFF call, no permit). Otherwise it takes a permit from the app-wide limiter — none
     * left throws {@link OffRateLimitedException} without calling OFF — calls OFF, and caches the answer. A failed
     * call throws before anything is cached.
     */
    private List<OffSearchItem> searchPass(String query, String lang, String countryTag) {
        String text = OffSearchQuery.sanitize(query);
        if (text.isEmpty()) {
            return List.of(); // nothing searchable: no OFF call, so no permit and nothing to cache
        }
        String key = lang + "|" + text;
        Optional<List<OffSearchItem>> cached = cache.get(key);
        if (cached.isPresent()) {
            return cached.get();
        }
        if (!limiter.tryAcquire()) {
            throw new OffRateLimitedException("the app-wide cap of " + limiter.perMinute()
                    + " OpenFoodFacts searches per minute is used up");
        }

        List<OffSearchHit> hits = openFoodFactsClient.searchByName(text, lang, countryTag, RESULT_LIMIT);
        Map<String, OffSearchItem> byBarcode = new LinkedHashMap<>();
        for (OffSearchHit hit : hits) {
            OffSearchItem item = toItem(hit);
            if (item != null) {
                byBarcode.putIfAbsent(item.barcode(), item);
            }
        }
        List<OffSearchItem> items = List.copyOf(byBarcode.values());
        cache.put(key, items);
        return items;
    }

    /**
     * The D6 rules: a usable name ({@code product_name_<lang>} first), kcal and protein present, plausible
     * numbers. Anything else is dropped (returns {@code null}).
     */
    static OffSearchItem toItem(OffSearchHit hit) {
        String name = firstNonBlank(hit.localizedName(), hit.productName());
        if (name == null) {
            return null;
        }
        Double kcal = hit.energyKcalPer100g();
        Double protein = hit.proteinsPer100g();
        if (kcal == null || protein == null) {
            return null;
        }
        if (kcal < 0 || kcal > MAX_KCAL_PER_100G
                || !gramsPlausible(protein) || !gramsPlausibleOrAbsent(hit.carbohydratesPer100g())
                || !gramsPlausibleOrAbsent(hit.fatPer100g())) {
            return null;
        }
        return new OffSearchItem(hit.code(), name, hit.brands(), kcal, protein, hit.carbohydratesPer100g(), hit.fatPer100g());
    }

    /**
     * The user's own foods are already in their list, and saving one again would hit the
     * {@code (user_id, barcode)} unique index. Applied <i>after</i> the fallback decision: a Hungarian
     * result that is all owned is still a Hungarian result, not a reason to show English ones.
     */
    private List<OffSearchItem> withoutOwned(List<OffSearchItem> items) {
        Set<String> owned = foodRepository.findOwnedBarcodes(
                currentUserProvider.getUserId(), items.stream().map(OffSearchItem::barcode).toList());
        return items.stream().filter(i -> !owned.contains(i.barcode())).toList();
    }

    private static boolean gramsPlausible(double grams) {
        return grams >= 0 && grams <= MAX_GRAMS_PER_100G;
    }

    private static boolean gramsPlausibleOrAbsent(Double grams) {
        return grams == null || gramsPlausible(grams);
    }

    private static String firstNonBlank(String... candidates) {
        for (String candidate : candidates) {
            if (candidate != null && !candidate.isBlank()) {
                return candidate.trim();
            }
        }
        return null;
    }

    private static OffSearchResponse ok(String language, boolean fellBackToEnglish, List<OffSearchItem> items) {
        return new OffSearchResponse(OffSearchStatus.OK, language, fellBackToEnglish, items);
    }

    private static OffSearchResponse failed(OffSearchStatus status, String language) {
        return new OffSearchResponse(status, language, false, List.of());
    }
}

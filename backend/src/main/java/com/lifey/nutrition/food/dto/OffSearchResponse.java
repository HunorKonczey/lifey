package com.lifey.nutrition.food.dto;

import java.util.List;

/**
 * Result of {@code GET /foods/off-search} (docs/84 D2).
 *
 * @param status            how the search went; never an HTTP error for an OFF problem
 * @param language          the language the returned items were searched in, {@code hu} or {@code en}
 * @param fellBackToEnglish {@code true} only when the user's-language search found nothing and
 *                          the English search did — so {@code items} is non-empty
 * @param items             at most 20, in OFF's relevance order
 */
public record OffSearchResponse(
        OffSearchStatus status,
        String language,
        boolean fellBackToEnglish,
        List<OffSearchItem> items
) {
}

package com.lifey.nutrition.food.service;

import com.lifey.nutrition.food.dto.OffSearchResponse;

public interface FoodNameSearchService {

    /**
     * Searches OpenFoodFacts by product name for the current user (docs/84): in {@code lang}
     * first — for {@code hu}, restricted to products sold in Hungary — and, only if that finds
     * nothing usable, in English. Never throws for an OpenFoodFacts problem; the status says it.
     *
     * @param query what the user typed
     * @param lang  {@code hu} or {@code en}; anything else is searched as {@code en}
     */
    OffSearchResponse search(String query, String lang);
}

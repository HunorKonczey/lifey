package com.lifey.nutrition.food.dto;

/**
 * How an OpenFoodFacts name search went. Anything but {@link #OK} comes with an empty item
 * list; the client says what happened under the own results instead of failing the dialog
 * (docs/84 D2).
 */
public enum OffSearchStatus {
    OK,
    /** OpenFoodFacts did not answer (timeout, connection failure, server error). */
    UNAVAILABLE,
    /** OpenFoodFacts, or our own cap on calls to it, said too many searches. */
    RATE_LIMITED
}

package com.lifey.nutrition.recipe.generation.exception;

/**
 * 400 — the wizard's answers contradict each other (a meat type with a
 * vegetarian or vegan diet). Rejected rather than silently ignored, so a client
 * bug shows up instead of producing a recipe nobody asked for.
 */
public class InvalidGenerationRequestException extends RuntimeException {

    public InvalidGenerationRequestException(String message) {
        super(message);
    }
}

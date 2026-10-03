package com.lifey.trainer.dto;

import com.lifey.settings.GoalsSource;

import java.time.Instant;

/**
 * Who last changed a client's nutrition goals, as the trainer sees it (docs/redesign-web/82 section 2.4).
 * {@code setByYou} tells the requesting trainer's own change from another trainer's; names are deliberately not
 * included, so one trainer never learns who else coaches the client.
 */
public record ClientNutritionGoalsSourceResponse(GoalsSource source, Instant setAt, boolean setByYou) {
}

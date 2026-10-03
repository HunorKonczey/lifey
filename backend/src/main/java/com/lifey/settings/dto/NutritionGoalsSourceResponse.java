package com.lifey.settings.dto;

import com.lifey.settings.GoalsSource;

import java.time.Instant;

/**
 * Who set the current user's nutrition goals (docs/redesign-web/82 section 2.4). {@code setAt} is null for
 * {@code UNKNOWN}; {@code setByName} is the trainer's display name for {@code TRAINER}, null when that account is
 * gone or for any other source.
 */
public record NutritionGoalsSourceResponse(GoalsSource source, Instant setAt, String setByName) {
}

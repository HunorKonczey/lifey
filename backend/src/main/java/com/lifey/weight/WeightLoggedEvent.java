package com.lifey.weight;

import java.time.LocalDate;

/**
 * A weigh-in was saved (published inside the creating transaction, so listeners wait for the commit). The weight package does
 * not know who cares: the trainer push (docs/85-trainer-push-plan.md) listens from the trainer package.
 *
 * @param date   the day the weigh-in is for, not when it was synced
 * @param weight kilograms, as stored
 */
public record WeightLoggedEvent(Long userId, LocalDate date, double weight) {
}

package com.lifey.trainer.dto;

import java.time.LocalDate;

/** One point of a client's recent weight history, for the dashboard sparkline. */
public record WeightTrendPoint(LocalDate date, double weightKg) {
}

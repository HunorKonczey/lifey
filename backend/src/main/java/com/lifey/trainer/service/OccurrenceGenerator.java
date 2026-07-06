package com.lifey.trainer.service;

import com.lifey.trainer.Recurrence;
import com.lifey.trainer.exception.EmptyRecurrenceException;
import com.lifey.trainer.exception.ScheduleHorizonExceededException;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.util.Arrays;
import java.util.EnumSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * Pure date arithmetic for materializing a {@code WorkoutSchedule}'s occurrences
 * (docs/personal_trainer/09-utemezett-edzesek-domain-backend.md). No time zone
 * involved anywhere: everything is {@link LocalDate}.
 */
final class OccurrenceGenerator {

    /** Sanity cap — daily for ~3 months tops out around 92; 100 leaves headroom without being unbounded. */
    static final int MAX_OCCURRENCES = 100;

    private OccurrenceGenerator() {
    }

    /**
     * @throws EmptyRecurrenceException       if the recurrence produces no dates in range
     * @throws ScheduleHorizonExceededException if it produces more than {@link #MAX_OCCURRENCES}
     */
    static List<LocalDate> generate(Recurrence recurrence, List<DayOfWeek> daysOfWeek, LocalDate startDate, LocalDate endDate) {
        List<LocalDate> dates = switch (recurrence) {
            case ONCE -> List.of(startDate);
            case DAILY -> startDate.datesUntil(endDate.plusDays(1)).toList();
            case WEEKLY -> {
                Set<DayOfWeek> selected = EnumSet.copyOf(daysOfWeek);
                yield startDate.datesUntil(endDate.plusDays(1))
                        .filter(d -> selected.contains(d.getDayOfWeek()))
                        .toList();
            }
        };

        if (dates.isEmpty()) {
            throw new EmptyRecurrenceException("Recurrence produces no occurrences in the given date range");
        }
        if (dates.size() > MAX_OCCURRENCES) {
            throw new ScheduleHorizonExceededException("Recurrence would create " + dates.size()
                    + " occurrences, more than the " + MAX_OCCURRENCES + " sanity cap");
        }
        return dates;
    }

    /** {@code MONDAY} -> {@code "MON"}, comma-joined, e.g. {@code "MON,THU"}. */
    static String formatDaysOfWeek(List<DayOfWeek> daysOfWeek) {
        return daysOfWeek.stream().map(OccurrenceGenerator::toCode).collect(Collectors.joining(","));
    }

    /** Inverse of {@link #formatDaysOfWeek}; {@code null}/blank input yields an empty list. */
    static List<DayOfWeek> parseDaysOfWeek(String csv) {
        if (csv == null || csv.isBlank()) {
            return List.of();
        }
        return Arrays.stream(csv.split(","))
                .map(OccurrenceGenerator::fromCode)
                .toList();
    }

    private static String toCode(DayOfWeek day) {
        return day.name().substring(0, 3);
    }

    private static DayOfWeek fromCode(String code) {
        String trimmed = code.trim();
        return Arrays.stream(DayOfWeek.values())
                .filter(day -> toCode(day).equals(trimmed))
                .findFirst()
                .orElseThrow(() -> new IllegalArgumentException("Not a recognized day-of-week code: " + trimmed));
    }
}

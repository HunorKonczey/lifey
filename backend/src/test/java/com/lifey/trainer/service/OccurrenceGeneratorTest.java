package com.lifey.trainer.service;

import com.lifey.trainer.Recurrence;
import com.lifey.trainer.exception.EmptyRecurrenceException;
import com.lifey.trainer.exception.ScheduleHorizonExceededException;
import org.junit.jupiter.api.Test;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.Month;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class OccurrenceGeneratorTest {

    @Test
    void once_producesSingleDate() {
        LocalDate date = LocalDate.of(2026, Month.JULY, 10);

        List<LocalDate> dates = OccurrenceGenerator.generate(Recurrence.ONCE, List.of(), date, date);

        assertThat(dates).containsExactly(date);
    }

    @Test
    void daily_producesEveryDayInclusive_acrossMonthBoundary() {
        List<LocalDate> dates = OccurrenceGenerator.generate(
                Recurrence.DAILY, List.of(), LocalDate.of(2026, Month.JANUARY, 30), LocalDate.of(2026, Month.FEBRUARY, 2));

        assertThat(dates).containsExactly(
                LocalDate.of(2026, Month.JANUARY, 30), LocalDate.of(2026, Month.JANUARY, 31),
                LocalDate.of(2026, Month.FEBRUARY, 1), LocalDate.of(2026, Month.FEBRUARY, 2));
    }

    @Test
    void daily_handlesLeapDay() {
        List<LocalDate> dates = OccurrenceGenerator.generate(
                Recurrence.DAILY, List.of(), LocalDate.of(2028, Month.FEBRUARY, 27), LocalDate.of(2028, Month.MARCH, 1));

        assertThat(dates).containsExactly(
                LocalDate.of(2028, Month.FEBRUARY, 27), LocalDate.of(2028, Month.FEBRUARY, 28),
                LocalDate.of(2028, Month.FEBRUARY, 29), LocalDate.of(2028, Month.MARCH, 1));
    }

    @Test
    void weekly_selectsOnlyMatchingDays() {
        // 2026-07-06 is a Monday.
        List<LocalDate> dates = OccurrenceGenerator.generate(
                Recurrence.WEEKLY, List.of(DayOfWeek.MONDAY, DayOfWeek.THURSDAY),
                LocalDate.of(2026, Month.JULY, 6), LocalDate.of(2026, Month.JULY, 19));

        assertThat(dates).containsExactly(
                LocalDate.of(2026, Month.JULY, 6), LocalDate.of(2026, Month.JULY, 9),
                LocalDate.of(2026, Month.JULY, 13), LocalDate.of(2026, Month.JULY, 16));
    }

    @Test
    void weekly_noMatchInRange_throwsEmptyRecurrence() {
        assertThatThrownBy(() -> OccurrenceGenerator.generate(
                Recurrence.WEEKLY, List.of(DayOfWeek.SUNDAY),
                LocalDate.of(2026, Month.JULY, 6), LocalDate.of(2026, Month.JULY, 10)))
                .isInstanceOf(EmptyRecurrenceException.class);
    }

    @Test
    void exceedsSanityCap_throwsHorizonExceeded() {
        assertThatThrownBy(() -> OccurrenceGenerator.generate(
                Recurrence.DAILY, List.of(), LocalDate.of(2026, Month.JANUARY, 1), LocalDate.of(2026, Month.JUNE, 1)))
                .isInstanceOf(ScheduleHorizonExceededException.class);
    }

    @Test
    void threeMonthDailyRange_staysUnderCap() {
        List<LocalDate> dates = OccurrenceGenerator.generate(
                Recurrence.DAILY, List.of(), LocalDate.of(2026, Month.JULY, 6), LocalDate.of(2026, Month.OCTOBER, 6));

        assertThat(dates).hasSizeLessThanOrEqualTo(OccurrenceGenerator.MAX_OCCURRENCES);
    }

    @Test
    void formatAndParseDaysOfWeek_roundTrip() {
        List<DayOfWeek> days = List.of(DayOfWeek.MONDAY, DayOfWeek.THURSDAY);

        String csv = OccurrenceGenerator.formatDaysOfWeek(days);
        assertThat(csv).isEqualTo("MON,THU");
        assertThat(OccurrenceGenerator.parseDaysOfWeek(csv)).containsExactly(DayOfWeek.MONDAY, DayOfWeek.THURSDAY);
    }

    @Test
    void parseDaysOfWeek_nullOrBlank_returnsEmptyList() {
        assertThat(OccurrenceGenerator.parseDaysOfWeek(null)).isEmpty();
        assertThat(OccurrenceGenerator.parseDaysOfWeek("")).isEmpty();
    }
}

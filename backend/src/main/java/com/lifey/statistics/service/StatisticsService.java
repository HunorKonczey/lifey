package com.lifey.statistics.service;

import com.lifey.statistics.dto.StatisticsResponse;

import java.time.LocalDate;

public interface StatisticsService {

    StatisticsResponse daily();

    /**
     * Same as {@link #daily()}, but anchors "today" on the given date instead
     * of the server's own clock — use this when the caller (e.g. the mobile
     * client) knows its own local date, so the day boundary doesn't depend on
     * the backend host's clock/timezone matching the client's.
     */
    StatisticsResponse daily(LocalDate today);

    StatisticsResponse weekly();

    StatisticsResponse weekly(LocalDate today);

    StatisticsResponse monthly();

    StatisticsResponse monthly(LocalDate today);

    /**
     * Same aggregation as {@link #daily(LocalDate)}, but scoped to an explicit
     * user rather than the current one — used by the trainer client-stats
     * endpoints (see docs/personal_trainer/03-backend-terv.md), which must
     * never let a trainer's own {@code CurrentUserProvider} identity leak into
     * the query. Callers are responsible for authorizing {@code userId} first
     * (e.g. via {@code TrainerAccessService.requireActiveClient}).
     */
    StatisticsResponse dailyForUser(Long userId, LocalDate today);

    StatisticsResponse weeklyForUser(Long userId, LocalDate today);

    StatisticsResponse monthlyForUser(Long userId, LocalDate today);

    /**
     * The same, anchored on today's date <em>in that user's own timezone</em> (their stored UTC offset)
     * rather than the server's: just after midnight local time the server's date can still be yesterday,
     * which made "today" reach back to the start of yesterday.
     */
    StatisticsResponse dailyForUser(Long userId);

    StatisticsResponse weeklyForUser(Long userId);

    StatisticsResponse monthlyForUser(Long userId);
}

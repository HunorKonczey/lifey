package com.lifey.trainer;

import com.lifey.trainer.service.WeeklyReportService;
import lombok.RequiredArgsConstructor;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDate;

/**
 * Fires the weekly trainer report email (docs/33-weekly-trainer-report-plan.md)
 * every Monday at 05:00 UTC, covering the previous Monday-to-Sunday week. Unlike
 * {@code WorkoutReminderJob}, this doesn't need a per-user-local-time tick: an
 * email waits in the inbox, so one fixed server moment is enough — by 05:00 UTC
 * Monday the previous ISO week is over in every timezone the app targets.
 * Single-instance assumption (no sent-log table): if the app happens to be down
 * at the firing, that week's report is simply skipped, same stance as
 * {@code WorkoutReminderJob}'s missed-reminder handling.
 */
@Component
@RequiredArgsConstructor
class TrainerWeeklyReportJob {

    private final WeeklyReportService weeklyReportService;
    private final Clock clock;

    @Scheduled(cron = "${lifey.jobs.trainer-weekly-report.cron}")
    @Transactional(readOnly = true)
    void sendWeeklyReports() {
        LocalDate weekStart = LocalDate.now(clock).minusDays(7);
        weeklyReportService.sendWeeklyReports(weekStart);
    }
}

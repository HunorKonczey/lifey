package com.lifey.trainer.service;

import java.time.LocalDate;

public interface WeeklyReportService {

    /**
     * Sends the weekly digest to every trainer with active clients, covering
     * the Monday-to-Sunday week starting at {@code weekStart} (docs/33-weekly-trainer-report-plan.md).
     */
    void sendWeeklyReports(LocalDate weekStart);
}

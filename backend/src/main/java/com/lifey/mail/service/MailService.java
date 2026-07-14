package com.lifey.mail.service;

import com.lifey.mail.WeeklyTrainerReport;
import com.lifey.user.User;

/**
 * Intent-based sending — callers never build subjects/bodies themselves, so
 * wording and language selection stay in one place (see {@code MailTemplateRenderer}
 * and {@code MailLanguageResolver}).
 */
public interface MailService {

    void sendWelcomeEmail(User user);

    void sendPasswordResetEmail(User user, String code);

    void sendTrainerInviteEmail(User client, User trainer, String acceptUrl, String declineUrl);

    /** Weekly digest of a trainer's active clients (docs/33-weekly-trainer-report-plan.md). */
    void sendWeeklyTrainerReport(User trainer, WeeklyTrainerReport report);
}

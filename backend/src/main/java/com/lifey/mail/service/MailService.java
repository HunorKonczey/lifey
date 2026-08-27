package com.lifey.mail.service;

import com.lifey.mail.MailLanguage;
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

    /**
     * The public marketing site's contact form (docs/landing_page/65 Prompt 8) — the one
     * message here with no {@link User} recipient, since the sender is an anonymous visitor,
     * not an account. Delivered to the team inbox with the visitor's own address as reply-to.
     * {@code language} comes straight from which locale the visitor was on, not a stored
     * preference — there is no account to store one against.
     */
    void sendContactMessage(String name, String email, String message, MailLanguage language);
}

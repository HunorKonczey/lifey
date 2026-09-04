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

    /**
     * A new trainer access request (docs/landing_page/66-trainer-billing-web-plan.md §2,
     * D-T1) — delivered to the team inbox, same path as {@link #sendContactMessage}, with
     * the requester's own address as reply-to. Always sent in English (an internal-facing
     * notification, not user-facing copy), unlike every other method here.
     */
    void sendTrainerRequestNotification(User requester, String motivation, Integer clientCount);

    /** The "you're in" email sent when a pending trainer request is approved (66 §2). */
    void sendTrainerRequestApproved(User user);
}

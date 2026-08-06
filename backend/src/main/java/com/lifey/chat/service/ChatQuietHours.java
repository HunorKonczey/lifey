package com.lifey.chat.service;

import com.lifey.settings.UserSettings;
import com.lifey.user.User;

import java.time.Instant;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;

/**
 * The §5.4 quiet-hours window: a local-time span in which chat pushes are held
 * back. The message still arrives — only the notification is suppressed, and
 * the reminder job picks it up once the window ends.
 *
 * <p>Local means <em>the user's</em> local, derived from
 * {@code User.utcOffsetMinutes} the same way {@code WorkoutReminderJob} and the
 * day-boundary logic in statistics do. A server-local window would silence the
 * wrong people as soon as anyone travelled or the app was deployed elsewhere.
 */
public final class ChatQuietHours {

    private ChatQuietHours() {
    }

    /**
     * @return true if {@code now}, in the user's local time, falls inside their
     * configured quiet window. False whenever the window is not fully
     * configured — a half-set window is not a window.
     */
    public static boolean isQuiet(User user, UserSettings settings, Instant now) {
        if (settings == null) {
            return false;
        }
        LocalTime start = settings.getChatQuietHoursStart();
        LocalTime end = settings.getChatQuietHoursEnd();
        if (start == null || end == null || start.equals(end)) {
            return false;
        }
        return contains(start, end, localTimeOf(user, now));
    }

    /** The user's wall clock at {@code instant}. */
    public static LocalTime localTimeOf(User user, Instant instant) {
        ZoneOffset offset = ZoneOffset.ofTotalSeconds(user.getUtcOffsetMinutes() * 60);
        return OffsetDateTime.ofInstant(instant, offset).toLocalTime();
    }

    /**
     * Half-open window {@code [start, end)}.
     *
     * <p>The interesting case is the normal one: quiet hours almost always run
     * across midnight (22:00–07:00), where {@code start > end} and the window is
     * the <em>union</em> of the two ends of the day rather than the span
     * between them. Getting this backwards would silence the whole working day
     * and notify all night.
     */
    static boolean contains(LocalTime start, LocalTime end, LocalTime time) {
        if (start.isBefore(end)) {
            return !time.isBefore(start) && time.isBefore(end);
        }
        return !time.isBefore(start) || time.isBefore(end);
    }
}

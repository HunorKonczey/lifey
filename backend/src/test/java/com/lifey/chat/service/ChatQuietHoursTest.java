package com.lifey.chat.service;

import com.lifey.settings.UserSettings;
import com.lifey.user.User;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.time.LocalTime;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * The window is local to the user and almost always runs across midnight, which
 * is the case worth pinning down: getting it backwards would silence the whole
 * working day and notify all night.
 */
class ChatQuietHoursTest {

    @Test
    void aDaytimeWindowIsTheSpanBetweenItsEnds() {
        assertThat(ChatQuietHours.contains(t(13, 0), t(15, 0), t(12, 59))).isFalse();
        assertThat(ChatQuietHours.contains(t(13, 0), t(15, 0), t(13, 0))).isTrue();
        assertThat(ChatQuietHours.contains(t(13, 0), t(15, 0), t(14, 59))).isTrue();
        // Half-open: the end itself is already outside.
        assertThat(ChatQuietHours.contains(t(13, 0), t(15, 0), t(15, 0))).isFalse();
    }

    @Test
    void anOvernightWindowWrapsAroundMidnight() {
        assertThat(ChatQuietHours.contains(t(22, 0), t(7, 0), t(21, 59))).isFalse();
        assertThat(ChatQuietHours.contains(t(22, 0), t(7, 0), t(22, 0))).isTrue();
        assertThat(ChatQuietHours.contains(t(22, 0), t(7, 0), t(23, 59))).isTrue();
        assertThat(ChatQuietHours.contains(t(22, 0), t(7, 0), t(0, 0))).isTrue();
        assertThat(ChatQuietHours.contains(t(22, 0), t(7, 0), t(6, 59))).isTrue();
        assertThat(ChatQuietHours.contains(t(22, 0), t(7, 0), t(7, 0))).isFalse();
    }

    @Test
    void theSameInstantFallsInOrOutDependingOnTheUsersOffset() {
        // 12:00 UTC, a 13:00–15:00 window: quiet at UTC+2, not at UTC.
        Instant noonUtc = Instant.parse("2026-08-06T12:00:00Z");
        UserSettings settings = quietHours(t(13, 0), t(15, 0));

        assertThat(ChatQuietHours.isQuiet(userAtOffset(120), settings, noonUtc)).isTrue();
        assertThat(ChatQuietHours.isQuiet(userAtOffset(0), settings, noonUtc)).isFalse();
        // West of UTC the same window has already passed for the day.
        assertThat(ChatQuietHours.isQuiet(userAtOffset(-300), settings, noonUtc)).isFalse();
    }

    @Test
    void aHalfConfiguredOrEmptyWindowIsNoWindow() {
        Instant now = Instant.parse("2026-08-06T12:00:00Z");
        User user = userAtOffset(0);

        assertThat(ChatQuietHours.isQuiet(user, null, now)).isFalse();
        assertThat(ChatQuietHours.isQuiet(user, quietHours(null, null), now)).isFalse();
        assertThat(ChatQuietHours.isQuiet(user, quietHours(t(13, 0), null), now)).isFalse();
        assertThat(ChatQuietHours.isQuiet(user, quietHours(null, t(15, 0)), now)).isFalse();
        // start == end would otherwise be either "always" or "never" depending
        // on which branch won; it means "no window".
        assertThat(ChatQuietHours.isQuiet(user, quietHours(t(12, 0), t(12, 0)), now)).isFalse();
    }

    private static LocalTime t(int hour, int minute) {
        return LocalTime.of(hour, minute);
    }

    private static User userAtOffset(int utcOffsetMinutes) {
        User user = new User();
        user.setId(1L);
        user.setUtcOffsetMinutes(utcOffsetMinutes);
        return user;
    }

    private static UserSettings quietHours(LocalTime start, LocalTime end) {
        UserSettings settings = new UserSettings();
        settings.setChatQuietHoursStart(start);
        settings.setChatQuietHoursEnd(end);
        return settings;
    }
}

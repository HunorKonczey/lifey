package com.lifey.chat.service;

import com.lifey.chat.spi.ChatPushPrefs;
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

        assertThat(ChatQuietHours.isQuiet(prefs(120, t(13, 0), t(15, 0)), noonUtc)).isTrue();
        assertThat(ChatQuietHours.isQuiet(prefs(0, t(13, 0), t(15, 0)), noonUtc)).isFalse();
        // West of UTC the same window has already passed for the day.
        assertThat(ChatQuietHours.isQuiet(prefs(-300, t(13, 0), t(15, 0)), noonUtc)).isFalse();
    }

    @Test
    void aHalfConfiguredOrEmptyWindowIsNoWindow() {
        Instant now = Instant.parse("2026-08-06T12:00:00Z");

        assertThat(ChatQuietHours.isQuiet(prefs(0, null, null), now)).isFalse();
        assertThat(ChatQuietHours.isQuiet(prefs(0, t(13, 0), null), now)).isFalse();
        assertThat(ChatQuietHours.isQuiet(prefs(0, null, t(15, 0)), now)).isFalse();
        // start == end would otherwise be either "always" or "never" depending
        // on which branch won; it means "no window".
        assertThat(ChatQuietHours.isQuiet(prefs(0, t(12, 0), t(12, 0)), now)).isFalse();
    }

    private static LocalTime t(int hour, int minute) {
        return LocalTime.of(hour, minute);
    }

    private static ChatPushPrefs prefs(int utcOffsetMinutes, LocalTime start, LocalTime end) {
        return new ChatPushPrefs(true, utcOffsetMinutes, start, end, false);
    }
}

package com.lifey.chat.dto;

import java.time.Instant;

/**
 * Mute this thread until the given instant, or unmute it with null (§I5).
 *
 * <p>An absolute instant rather than a duration, for two reasons: the client
 * already offers fixed choices ("1 hour", "until tomorrow", "always"), and an
 * instant expires by itself — nothing has to sweep expired mutes.
 */
public record MuteRequest(Instant mutedUntil) {
}

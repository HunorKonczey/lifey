package com.lifey.chat;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.time.Duration;

/**
 * Bound from {@code lifey.chat.*} (see application.yml).
 *
 * @param enabled             kill switch: when false, existing threads stay
 *                            readable but sending is rejected with 503 — the
 *                            incident-response lever from §8/I7
 * @param maxBodyLength       max characters per message, checked after trimming
 * @param defaultPageSize     page size when the caller doesn't ask for one
 * @param maxPageSize         upper bound a caller can ask for
 * @param rateLimitPerMinute  per-user send budget, abuse protection (§7.2)
 * @param rateLimitPerDay     per-user daily send budget
 * @param streamTimeout       how long one SSE connection lives before the server
 *                            closes it and the client reconnects; a bounded
 *                            lifetime is the backstop against emitter leaks (§9)
 * @param streamCatchUpLimit  most messages a reconnect will replay from
 *                            {@code Last-Event-ID}; beyond it the server sends
 *                            {@code resync} and the client reloads over REST
 * @param streamTombstoneWindow how far back a reconnect replays <em>deletions</em>
 *                            of messages the client already holds. The message
 *                            gap fill only walks forward, so a deletion that
 *                            happened while the client was away has no other
 *                            way home (§17.5). Bounded because this is a sweep
 *                            over already-delivered rows on every connect, and
 *                            a client that has been gone longer than this
 *                            window is better served by a full reload anyway
 * @param presenceTtl         how long a reported "I am looking at this thread"
 *                            stays believed without a refresh (§4.3)
 * @param pushCoalesceWindow  at most one push per thread per window, so a burst
 *                            of messages is one interruption (§5.3)
 * @param reminderAfter       how long a message stays unread before the reminder
 *                            job comes back for it (§5.4)
 * @param reminderDailyCap    most reminders one user can get per day
 * @param emailFallbackEnabled  §5.5 — off by default: a mail about an unread
 *                              chat message is easy to read as spam, and the
 *                              metrics for how often it would fire come first
 * @param emailFallbackAfter  how long unread before the mail goes out, and only
 *                            to a user with no push device at all
 * @param attachmentMaxBytes  largest image upload accepted, measured on the raw
 *                            upload before re-encoding; the chat's own budget,
 *                            below the container's shared multipart limit
 * @param attachmentMaxSide   longest side of the stored image, aspect preserved
 * @param attachmentThumbnailSize longest side of the thumbnail the bubble
 *                            shows; aspect-preserving, not square-cropped
 * @param typingThrottle      shortest gap between two typing frames for the
 *                            same user and thread, on top of the clients' own
 *                            throttling; zero disables the server-side guard
 * @param searchMinLength     shortest term the in-thread search will actually
 *                            run; below it the answer is an empty page, because
 *                            the clients search as you type
 * @param typingTtl           how long a received typing hint stays on screen
 *                            without a refresh — reported to clients only as a
 *                            shared constant, since nothing about it is stored
 */
@ConfigurationProperties(prefix = "lifey.chat")
public record ChatProperties(
        boolean enabled,
        int maxBodyLength,
        int defaultPageSize,
        int maxPageSize,
        int rateLimitPerMinute,
        int rateLimitPerDay,
        Duration streamTimeout,
        int streamCatchUpLimit,
        Duration streamTombstoneWindow,
        Duration presenceTtl,
        Duration pushCoalesceWindow,
        Duration reminderAfter,
        int reminderDailyCap,
        boolean emailFallbackEnabled,
        Duration emailFallbackAfter,
        long attachmentMaxBytes,
        int attachmentMaxSide,
        int attachmentThumbnailSize,
        Duration typingThrottle,
        Duration typingTtl,
        int searchMinLength
) {
}

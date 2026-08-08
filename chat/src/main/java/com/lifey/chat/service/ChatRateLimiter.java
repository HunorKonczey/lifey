package com.lifey.chat.service;

import com.lifey.chat.ChatProperties;
import com.lifey.chat.exception.ChatRateLimitedException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Per-user send budget (§7.2). Two fixed windows — a minute and a day — held in
 * memory, which is the right shape for what this is: abuse protection, not
 * accounting. On a multi-instance deployment each instance enforces its own
 * share; that under-counts, and that is acceptable for a limit whose job is to
 * stop a runaway client, not to bill anyone.
 */
@Component
@RequiredArgsConstructor
public class ChatRateLimiter {

    /** Above this many tracked users, evict day-old entries before adding more. */
    private static final int PRUNE_THRESHOLD = 10_000;

    private final ChatProperties properties;
    private final Map<Long, Counters> counters = new ConcurrentHashMap<>();

    /** @throws ChatRateLimitedException if the caller is over either window's budget */
    public void requireSendAllowance(Long userId) {
        Instant now = Instant.now();
        pruneIfLarge(now);
        Counters userCounters = counters.computeIfAbsent(userId, id -> new Counters(now));
        if (!userCounters.tryAcquire(now, properties.rateLimitPerMinute(), properties.rateLimitPerDay())) {
            throw new ChatRateLimitedException("Message rate limit exceeded");
        }
    }

    /**
     * Bounds the map for a process that never restarts. A prune racing with a
     * {@code computeIfAbsent} can hand one user a fresh window — harmless at
     * this granularity, and far cheaper than locking the whole map.
     */
    private void pruneIfLarge(Instant now) {
        if (counters.size() < PRUNE_THRESHOLD) {
            return;
        }
        counters.values().removeIf(entry -> entry.isIdleSince(now));
    }

    private static final class Counters {

        private Instant minuteStart;
        private int minuteCount;
        private Instant dayStart;
        private int dayCount;

        private Counters(Instant now) {
            this.minuteStart = now;
            this.dayStart = now;
        }

        private synchronized boolean tryAcquire(Instant now, int perMinute, int perDay) {
            if (Duration.between(minuteStart, now).toMinutes() >= 1) {
                minuteStart = now;
                minuteCount = 0;
            }
            if (Duration.between(dayStart, now).toDays() >= 1) {
                dayStart = now;
                dayCount = 0;
            }
            if (minuteCount >= perMinute || dayCount >= perDay) {
                return false;
            }
            minuteCount++;
            dayCount++;
            return true;
        }

        private synchronized boolean isIdleSince(Instant now) {
            return Duration.between(dayStart, now).toDays() >= 1;
        }
    }
}

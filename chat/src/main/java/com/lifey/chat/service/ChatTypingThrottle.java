package com.lifey.chat.service;

import com.lifey.chat.ChatProperties;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * How often one user's typing signal is allowed to reach a thread.
 *
 * <p>The clients throttle too, at a longer interval — this exists because a
 * keystroke-driven endpoint is the easiest thing in the API to hammer, whether
 * by a bug in a client or on purpose, and every accepted call is a frame
 * written to somebody else's socket. The send rate limiter is not the right
 * tool: it counts a budget the user would then be unable to spend on real
 * messages, and typing is not traffic worth accounting for.
 *
 * <p>In memory and per instance, exactly like {@link ChatPresenceRegistry} and
 * {@link ChatRateLimiter}: dropping an occasional typing hint costs nothing.
 */
@Component
@RequiredArgsConstructor
public class ChatTypingThrottle {

    /** Above this many tracked threads, drop the stale entries before adding more. */
    private static final int PRUNE_THRESHOLD = 10_000;

    private final ChatProperties properties;
    private final Map<Key, Instant> lastSignal = new ConcurrentHashMap<>();

    /**
     * @return true if this signal should be broadcast, false if it arrived too
     * soon after the previous one for the same user and thread
     */
    public boolean allow(Long conversationId, Long userId) {
        Duration interval = properties.typingThrottle();
        if (interval == null || interval.isZero() || interval.isNegative()) {
            return true;
        }
        Instant now = Instant.now();
        pruneIfLarge(now, interval);

        Key key = new Key(conversationId, userId);
        // merge() rather than get-then-put: two keystrokes racing must not both
        // come out allowed.
        Instant stored = lastSignal.merge(key, now,
                (previous, candidate) -> previous.isAfter(candidate.minus(interval)) ? previous : candidate);
        return stored.equals(now);
    }

    private void pruneIfLarge(Instant now, Duration interval) {
        if (lastSignal.size() < PRUNE_THRESHOLD) {
            return;
        }
        lastSignal.values().removeIf(at -> at.isBefore(now.minus(interval)));
    }

    private record Key(Long conversationId, Long userId) {
    }
}

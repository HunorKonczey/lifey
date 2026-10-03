package com.lifey.user;

import io.micrometer.core.instrument.MeterRegistry;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Stamps {@code users.last_active_at} for an authenticated request (docs/redesign-web/82 section 2.3).
 *
 * <p>Two layers keep it cheap. An in-memory map remembers when each user was last written by this instance, so
 * the common case (a user making many requests a minute) costs one hash lookup and no database round trip. The
 * SQL itself is conditional ({@link UserRepository#touchLastActive}), so with several instances a user is still
 * written at most about once per window rather than once per instance per request.
 *
 * <p>It must never make a request fail or slow: any exception is swallowed, logged at debug and counted in
 * {@code lifey.user.activity.touch.failures} — a counter that stays at zero is how "it never updates" would show.
 */
@Slf4j
@Component
public class UserActivityTracker {

    /** One write per user per this long, per instance. Also the accuracy of the stamp. */
    static final Duration THROTTLE = Duration.ofMinutes(5);

    /** The map only needs to hold recently active users; past this it is simply emptied and refills. */
    private static final int MAX_TRACKED_USERS = 20_000;

    private final UserRepository userRepository;
    private final Clock clock;
    private final MeterRegistry meterRegistry;
    private final ConcurrentHashMap<Long, Instant> lastWrite = new ConcurrentHashMap<>();

    public UserActivityTracker(UserRepository userRepository, Clock clock, MeterRegistry meterRegistry) {
        this.userRepository = userRepository;
        this.clock = clock;
        this.meterRegistry = meterRegistry;
    }

    /** Records that [userId] just made an authenticated request. Never throws. */
    public void touch(Long userId) {
        if (userId == null) {
            return;
        }
        Instant now = clock.instant();
        Instant threshold = now.minus(THROTTLE);
        Instant previous = lastWrite.get(userId);
        if (previous != null && previous.isAfter(threshold)) {
            return;
        }
        if (lastWrite.size() >= MAX_TRACKED_USERS) {
            lastWrite.clear();
        }
        // Remembered before the write: concurrent requests of the same user must not all reach the database.
        lastWrite.put(userId, now);
        try {
            userRepository.touchLastActive(userId, now, threshold);
        } catch (RuntimeException e) {
            // A failed stamp is retried by the user's next request after the throttle; forget the optimistic entry
            // so that is not delayed further.
            lastWrite.remove(userId, now);
            meterRegistry.counter("lifey.user.activity.touch.failures").increment();
            log.debug("Could not stamp last_active_at for user {}", userId, e);
        }
    }
}

package com.lifey.user;

import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;

@ExtendWith(MockitoExtension.class)
class UserActivityTrackerTest {

    private static final Instant T0 = Instant.parse("2026-10-03T08:00:00Z");

    @Mock
    UserRepository userRepository;

    private MutableClock clock;
    private SimpleMeterRegistry meters;
    private UserActivityTracker tracker;

    @BeforeEach
    void setUp() {
        clock = new MutableClock(T0);
        meters = new SimpleMeterRegistry();
        tracker = new UserActivityTracker(userRepository, clock, meters);
    }

    @Test
    void firstRequestWritesTheStamp_withTheThresholdTheSqlIsConditionalOn() {
        tracker.touch(7L);

        verify(userRepository).touchLastActive(7L, T0, T0.minus(UserActivityTracker.THROTTLE));
    }

    @Test
    void repeatedRequestsInsideTheWindowNeverReachTheDatabase() {
        tracker.touch(7L);
        clock.advance(Duration.ofMinutes(4));
        tracker.touch(7L);
        tracker.touch(7L);

        verify(userRepository, times(1)).touchLastActive(anyLong(), any(), any());
    }

    @Test
    void aRequestAfterTheWindowWritesAgain() {
        tracker.touch(7L);
        clock.advance(UserActivityTracker.THROTTLE.plusSeconds(1));
        tracker.touch(7L);

        verify(userRepository, times(2)).touchLastActive(anyLong(), any(), any());
    }

    @Test
    void usersAreThrottledIndependently() {
        tracker.touch(1L);
        tracker.touch(2L);

        verify(userRepository).touchLastActive(1L, T0, T0.minus(UserActivityTracker.THROTTLE));
        verify(userRepository).touchLastActive(2L, T0, T0.minus(UserActivityTracker.THROTTLE));
    }

    @Test
    void aMissingUserIdIsIgnored() {
        tracker.touch(null);

        verify(userRepository, never()).touchLastActive(anyLong(), any(), any());
    }

    @Test
    void aFailingWriteNeverReachesTheCaller_isCounted_andIsRetriedByTheNextRequest() {
        doThrow(new IllegalStateException("db down")).when(userRepository).touchLastActive(anyLong(), any(), any());

        assertThatCode(() -> tracker.touch(7L)).doesNotThrowAnyException();
        assertThat(meters.counter("lifey.user.activity.touch.failures").count()).isEqualTo(1.0);

        // The optimistic throttle entry was dropped, so the very next request tries again rather than waiting five minutes.
        assertThatCode(() -> tracker.touch(7L)).doesNotThrowAnyException();
        verify(userRepository, times(2)).touchLastActive(anyLong(), any(), any());
        assertThat(meters.counter("lifey.user.activity.touch.failures").count()).isEqualTo(2.0);
    }

    /** A clock the test can move forward. */
    private static final class MutableClock extends Clock {
        private Instant now;

        MutableClock(Instant start) {
            this.now = start;
        }

        void advance(Duration by) {
            now = now.plus(by);
        }

        @Override
        public java.time.ZoneId getZone() {
            return ZoneOffset.UTC;
        }

        @Override
        public Clock withZone(java.time.ZoneId zone) {
            return this;
        }

        @Override
        public Instant instant() {
            return now;
        }
    }
}

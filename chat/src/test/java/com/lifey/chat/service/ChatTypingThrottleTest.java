package com.lifey.chat.service;

import com.lifey.chat.ChatProperties;
import org.junit.jupiter.api.Test;

import java.time.Duration;
import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.stream.IntStream;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * The server's own guard on a keystroke-driven endpoint: the clients throttle
 * too, but every accepted call writes a frame to somebody else's socket, so a
 * misbehaving client must not be able to turn typing into a flood (§19.4/3).
 */
class ChatTypingThrottleTest {

    private static final Long CONVERSATION_ID = 12L;
    private static final Long USER_ID = 7L;

    @Test
    void theFirstSignalGoesThroughAndTheNextOneIsSwallowed() {
        ChatTypingThrottle throttle = throttle(Duration.ofSeconds(30));

        assertThat(throttle.allow(CONVERSATION_ID, USER_ID)).isTrue();
        assertThat(throttle.allow(CONVERSATION_ID, USER_ID)).isFalse();
    }

    @Test
    void theWindowIsPerThreadAndPerUser() {
        ChatTypingThrottle throttle = throttle(Duration.ofSeconds(30));
        throttle.allow(CONVERSATION_ID, USER_ID);

        // Someone else writing in the same thread, and the same person writing
        // in another one, are different signals — neither is a repeat.
        assertThat(throttle.allow(CONVERSATION_ID, 88L)).isTrue();
        assertThat(throttle.allow(99L, USER_ID)).isTrue();
    }

    @Test
    void aZeroWindowDisablesTheGuard() {
        ChatTypingThrottle throttle = throttle(Duration.ZERO);

        assertThat(throttle.allow(CONVERSATION_ID, USER_ID)).isTrue();
        assertThat(throttle.allow(CONVERSATION_ID, USER_ID)).isTrue();
    }

    @Test
    void concurrentKeystrokesLetExactlyOneThrough() throws Exception {
        ChatTypingThrottle throttle = throttle(Duration.ofSeconds(30));
        int threads = 16;

        try (ExecutorService pool = Executors.newFixedThreadPool(threads)) {
            List<Callable<Boolean>> calls = IntStream.range(0, threads)
                    .<Callable<Boolean>>mapToObj(i -> () -> throttle.allow(CONVERSATION_ID, USER_ID))
                    .toList();
            List<Future<Boolean>> results = pool.invokeAll(calls);

            long allowed = 0;
            for (Future<Boolean> result : results) {
                if (result.get()) {
                    allowed++;
                }
            }
            // A read-then-write implementation would let several through here.
            assertThat(allowed).isEqualTo(1);
        }
    }

    private static ChatTypingThrottle throttle(Duration interval) {
        return new ChatTypingThrottle(new ChatProperties(true, 2000, 30, 100, 30, 600,
                Duration.ofMinutes(5), 200, Duration.ofDays(7), Duration.ofMinutes(2),
                Duration.ofSeconds(60), Duration.ofMinutes(30), 1, false,
                Duration.ofHours(24), 8L * 1024 * 1024, 1600, 400,
                interval, Duration.ofSeconds(5), 2));
    }
}

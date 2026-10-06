package com.lifey.nutrition.food.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.time.Duration;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;

class OffSearchLimiterTest {

    private MutableClock clock;

    @BeforeEach
    void setUp() {
        clock = new MutableClock();
    }

    @Test
    void allowsTheLimitThenRefuses() {
        OffSearchLimiter limiter = new OffSearchLimiter(3, clock);

        assertThat(limiter.tryAcquire()).isTrue();
        assertThat(limiter.tryAcquire()).isTrue();
        assertThat(limiter.tryAcquire()).isTrue();
        assertThat(limiter.tryAcquire()).isFalse();
        assertThat(limiter.tryAcquire()).isFalse();
    }

    @Test
    void aRefusalDoesNotCountAsACall() {
        OffSearchLimiter limiter = new OffSearchLimiter(1, clock);
        assertThat(limiter.tryAcquire()).isTrue();
        for (int i = 0; i < 5; i++) {
            assertThat(limiter.tryAcquire()).isFalse();
        }

        clock.advance(Duration.ofSeconds(60));

        assertThat(limiter.tryAcquire()).isTrue();
    }

    @Test
    void theWindowSlides_aCallStopsCountingAMinuteLater() {
        OffSearchLimiter limiter = new OffSearchLimiter(2, clock);
        assertThat(limiter.tryAcquire()).isTrue(); // t = 0
        clock.advance(Duration.ofSeconds(30));
        assertThat(limiter.tryAcquire()).isTrue(); // t = 30
        assertThat(limiter.tryAcquire()).isFalse();

        clock.advance(Duration.ofSeconds(29)); // t = 59: both still count
        assertThat(limiter.tryAcquire()).isFalse();

        clock.advance(Duration.ofSeconds(1)); // t = 60: the first one has left the window
        assertThat(limiter.tryAcquire()).isTrue();
        assertThat(limiter.tryAcquire()).isFalse(); // the t = 30 call and the new one

        clock.advance(Duration.ofSeconds(30)); // t = 90: the second has left
        assertThat(limiter.tryAcquire()).isTrue();
    }

    @Test
    void zeroOrLessAllowsNothing_anOffSwitch() {
        assertThat(new OffSearchLimiter(0, clock).tryAcquire()).isFalse();
        assertThat(new OffSearchLimiter(-5, clock).tryAcquire()).isFalse();
    }

    @Test
    void exactlyTheLimitGetsThroughUnderConcurrency() throws InterruptedException {
        OffSearchLimiter limiter = new OffSearchLimiter(8, clock);
        int threads = 64;
        ExecutorService pool = Executors.newFixedThreadPool(threads);
        CountDownLatch start = new CountDownLatch(1);
        CountDownLatch done = new CountDownLatch(threads);
        AtomicInteger granted = new AtomicInteger();
        for (int i = 0; i < threads; i++) {
            pool.submit(() -> {
                try {
                    start.await();
                    if (limiter.tryAcquire()) {
                        granted.incrementAndGet();
                    }
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                } finally {
                    done.countDown();
                }
            });
        }
        start.countDown();
        done.await();
        pool.shutdown();

        assertThat(granted.get()).isEqualTo(8);
    }
}

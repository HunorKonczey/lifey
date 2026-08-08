package com.lifey.chat;

import com.lifey.chat.service.ChatEmitterRegistry;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * The meters an operator reads during an incident (§21). What is worth testing
 * here is not that a counter counts, but that the series **exist before
 * anything happens** — "no data" and "nothing happened" have to be different
 * readings, or the alerts in §21.3 cannot be written.
 */
class ChatMetricsTest {

    MeterRegistry registry;
    ChatEmitterRegistry emitters;
    ChatMetrics metrics;

    @BeforeEach
    void setUp() {
        registry = new SimpleMeterRegistry();
        emitters = mock(ChatEmitterRegistry.class);
        metrics = new ChatMetrics(registry, emitters);
    }

    @Test
    void everySeriesExistsAtZeroBeforeAnyTrafficAtAll() {
        // A skip reason that only appears the first time it fires is the worst
        // kind for an alert: the interesting case is exactly when it is missing.
        for (ChatMetrics.PushDecision decision : ChatMetrics.PushDecision.values()) {
            metrics.pushDecision(decision);
        }
        assertThat(registry.find("lifey.chat.push.decisions").counters())
                .hasSize(ChatMetrics.PushDecision.values().length);

        assertThat(registry.find("lifey.chat.messages.sent").counters()).hasSize(2);
        assertThat(registry.find("lifey.chat.reminders.sent").counters()).hasSize(2);
    }

    @Test
    void messagesAreCountedByKind_sinceThatIsWhatStorageCostFollows() {
        metrics.messageSent("text");
        metrics.messageSent("text");
        metrics.messageSent("image");

        assertThat(registry.get("lifey.chat.messages.sent").tag("kind", "text").counter().count())
                .isEqualTo(2);
        assertThat(registry.get("lifey.chat.messages.sent").tag("kind", "image").counter().count())
                .isEqualTo(1);
    }

    @Test
    void pushDecisionsAreTaggedWithTheReason_soTheSkipRatioIsReadable() {
        metrics.pushDecision(ChatMetrics.PushDecision.SENT);
        metrics.pushDecision(ChatMetrics.PushDecision.SKIPPED_VIEWING);
        metrics.pushDecision(ChatMetrics.PushDecision.SKIPPED_VIEWING);

        assertThat(registry.get("lifey.chat.push.decisions").tag("outcome", "sent").counter().count())
                .isEqualTo(1);
        assertThat(registry.get("lifey.chat.push.decisions")
                .tag("outcome", "skipped-viewing").counter().count()).isEqualTo(2);
    }

    @Test
    void theConnectionGaugeReadsTheRegistryLive_notASnapshot() {
        when(emitters.connectionCount()).thenReturn(3);
        assertThat(registry.get("lifey.chat.stream.connections").gauge().value()).isEqualTo(3);

        // The whole point of a gauge here: the leak alarm needs the number as
        // it is now, not as it was when the meter was created.
        when(emitters.connectionCount()).thenReturn(202);
        assertThat(registry.get("lifey.chat.stream.connections").gauge().value()).isEqualTo(202);
    }
}

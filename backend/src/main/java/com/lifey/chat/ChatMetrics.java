package com.lifey.chat;

import com.lifey.chat.service.ChatEmitterRegistry;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.Gauge;
import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.stereotype.Component;

/**
 * The four numbers the chat is worth watching by
 * (docs/chat/40-trainer-chat-plan.md I7, §21).
 *
 * <p>One class rather than {@code MeterRegistry} injected in five places: the
 * meter names and tag values are a contract with whoever reads them, and a
 * typo in a string literal at the call site is a metric that silently splits
 * into two series. Here they are named once.
 *
 * <p>Counters are pre-registered in the constructor, not created lazily on
 * first use. A counter that only appears after the first event is the worst
 * kind for an alert: "no data" and "nothing happened" become the same reading,
 * and the interesting case — pushes suddenly all being skipped — is exactly
 * when a series would be missing.
 */
@Component
public class ChatMetrics {

    /** Why a push was or was not sent. Tag values of {@code lifey.chat.push.decisions}. */
    public enum PushDecision {
        SENT("sent"),
        /** §5.1 — they are looking at the thread, so there is nothing to interrupt. */
        SKIPPED_VIEWING("skipped-viewing"),
        SKIPPED_DISABLED("skipped-disabled"),
        SKIPPED_QUIET_HOURS("skipped-quiet-hours"),
        SKIPPED_MUTED("skipped-muted"),
        /** §5.3 — inside the coalescing window of a push already sent. */
        SKIPPED_COALESCED("skipped-coalesced");

        private final String tag;

        PushDecision(String tag) {
            this.tag = tag;
        }
    }

    private static final String MESSAGES_SENT = "lifey.chat.messages.sent";
    private static final String PUSH_DECISIONS = "lifey.chat.push.decisions";
    private static final String REMINDERS_SENT = "lifey.chat.reminders.sent";
    private static final String STREAM_CONNECTIONS = "lifey.chat.stream.connections";

    private final MeterRegistry registry;

    public ChatMetrics(MeterRegistry registry, ChatEmitterRegistry emitters) {
        this.registry = registry;

        // The §9 leak alarm. A gauge, not a counter: what matters is how many
        // emitters are open *now* — a number that keeps climbing while nobody
        // is using the app is a leak, and it is the only signal for one.
        Gauge.builder(STREAM_CONNECTIONS, emitters, ChatEmitterRegistry::connectionCount)
                .description("Chat SSE connections currently open on this instance")
                .register(registry);

        for (String kind : new String[]{"text", "image"}) {
            messagesSent(kind);
        }
        for (PushDecision decision : PushDecision.values()) {
            pushDecisions(decision);
        }
        for (String channel : new String[]{"push", "email"}) {
            remindersSent(channel);
        }
    }

    /** @param kind {@code text} or {@code image} — the split the storage cost follows */
    public void messageSent(String kind) {
        messagesSent(kind).increment();
    }

    /**
     * Every push decision, sent or skipped, with the reason. The ratio is the
     * point: a healthy chat skips plenty (people are reading), but *all*
     * skipped with one reason dominating is a bug in that gate.
     */
    public void pushDecision(PushDecision decision) {
        pushDecisions(decision).increment();
    }

    /** @param channel {@code push} or {@code email} — §5.4 and the §5.5 fallback */
    public void reminderSent(String channel) {
        remindersSent(channel).increment();
    }

    private Counter messagesSent(String kind) {
        return Counter.builder(MESSAGES_SENT)
                .description("Chat messages accepted and stored")
                .tag("kind", kind)
                .register(registry);
    }

    private Counter pushDecisions(PushDecision decision) {
        return Counter.builder(PUSH_DECISIONS)
                .description("Chat push notifications sent, or skipped with the reason why")
                .tag("outcome", decision.tag)
                .register(registry);
    }

    private Counter remindersSent(String channel) {
        return Counter.builder(REMINDERS_SENT)
                .description("Unread-chat reminders delivered by ChatUnreadReminderJob")
                .tag("channel", channel)
                .register(registry);
    }
}

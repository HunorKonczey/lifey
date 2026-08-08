package com.lifey.chat.spi.http;

import com.lifey.chat.ChatMetrics;
import com.lifey.chat.spi.ChatPushNotification;
import com.lifey.chat.spi.ChatPushSender;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import java.util.Map;

/**
 * {@link ChatPushSender} over {@code lifey-api}'s internal API (§6.1).
 *
 * <p><b>Why the push did not come along.</b> The Firebase Admin SDK (gRPC +
 * protobuf + the Google API client) loads enough classes that the monolith needs
 * 192 MB of metaspace — a 96 MB cap killed it mid-startup, which is why its
 * Dockerfile gives metaspace the larger share. Keeping that SDK out of this JVM
 * is what lets the chat run with a small metaspace and spend the difference on
 * heap, where the long-lived SSE connections actually live (§8.1).
 *
 * <p><b>Never throws.</b> That is the port's contract, and here it is load
 * bearing: this runs in an {@code AFTER_COMMIT} listener for a message that is
 * already stored and already served over REST. A notification problem must not
 * surface to the sender as a failed send. Anything dropped is picked up by
 * {@code ChatUnreadReminderJob} (§5.4) — the safety net that was designed for
 * exactly this, back when the failure mode was APNs dropping a push rather than
 * an HTTP hop.
 */
@Slf4j
@Component
@RequiredArgsConstructor
class HttpChatPushSender implements ChatPushSender {

    private final RestClient monolithRestClient;
    private final MonolithProperties properties;
    private final ChatMetrics metrics;

    @Override
    public void send(Long userId, ChatPushNotification notification) {
        if (!properties.isConfigured()) {
            // Local runs without a monolith next door: log and move on rather
            // than pretending a notification went out.
            log.debug("No monolith configured; skipping chat push for user {}", userId);
            return;
        }
        try {
            monolithRestClient.post()
                    .uri("/internal/push")
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(new PushRequest(
                            userId,
                            notification.title(),
                            notification.body(),
                            notification.data(),
                            notification.collapseKey()))
                    .retrieve()
                    .toBodilessEntity();
            metrics.internalPush(ChatMetrics.InternalCallOutcome.OK);
        } catch (RuntimeException ex) {
            // Ids only, never the body (§7.4) — the notification text is the
            // message text.
            log.error("Internal push call failed for user {}", userId, ex);
            metrics.internalPush(ChatMetrics.InternalCallOutcome.FAILED);
        }
    }

    /**
     * Only the §5.5 email fallback asks, and that stays off after the
     * extraction (§6.3) — so rather than build an endpoint nothing calls, this
     * answers "yes, assume they are reachable". The effect is that the reminder
     * job always takes the push branch, which is what it does today with the
     * flag off anyway.
     */
    @Override
    public boolean hasRegisteredDevice(Long userId) {
        return true;
    }

    /** Wire format of {@code POST /internal/push}. Mirrored on the monolith side. */
    private record PushRequest(
            Long userId,
            String title,
            String body,
            Map<String, String> data,
            String collapseKey
    ) {
    }
}

package com.lifey.internal;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.time.Duration;

/**
 * Bound from {@code lifey.internal.*} — everything about this application's seam
 * with the other service in the deployment
 * (docs/chat/44-chat-service-extraction-plan.md §5.5).
 *
 * @param token          shared secret that every inbound {@code /internal/**}
 *                       caller must present as {@code X-Lifey-Internal}, and
 *                       that outbound calls send.
 *                       <p>
 *                       <b>Empty means the internal API is closed</b>, not open:
 *                       with no secret configured every inbound call is
 *                       rejected. A misconfigured deployment therefore loses
 *                       push, which is loud and recoverable — the alternative
 *                       default would be an unauthenticated endpoint able to
 *                       notify any user.
 * @param chatUrl        origin of {@code lifey-chat}, no trailing slash. Empty
 *                       means the chat still runs inside this application, so
 *                       there is nobody to notify.
 * @param connectTimeout short by design: the revoke webhook fires after the
 *                       revoke has already committed, so a slow chat service
 *                       must not hold a request thread. A lost webhook is
 *                       covered by the chat's daily reconciliation sweep (§5.4).
 */
@ConfigurationProperties(prefix = "lifey.internal")
public record InternalApiProperties(
        String token,
        String chatUrl,
        Duration connectTimeout,
        Duration readTimeout
) {

    public boolean isConfigured() {
        return token != null && !token.isBlank();
    }

    /** Whether the chat lives in another service that needs telling about things. */
    public boolean hasChatService() {
        return chatUrl != null && !chatUrl.isBlank();
    }
}

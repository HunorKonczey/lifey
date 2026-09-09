package com.lifey.billing.controller.webhook;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.lifey.billing.PubSubTokenVerifier;
import com.lifey.billing.entity.SubscriptionProvider;
import com.lifey.billing.entity.SubscriptionStatus;
import com.lifey.billing.service.SubscriptionWriter;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.Optional;

/**
 * {@code POST /api/v1/webhooks/play} — Play Real-time developer notifications
 * (RTDN) via a Pub/Sub push subscription (docs/landing_page/64-billing-backend-plan.md
 * §6.2). Public (see {@code SecurityConfig.PUBLIC_ENDPOINTS}), authenticated
 * by the push subscription's own OIDC bearer token — {@link
 * PubSubTokenVerifier}, not our own JWT scheme. Reads the raw body rather
 * than {@code @RequestBody}, matching the Stripe webhook's reasoning (`64`
 * Prompt 5): simpler to parse once with one Jackson 2 {@link ObjectMapper}
 * (the one {@code SecurityConfig} already defines) than to fight Spring Boot
 * 4's default Jackson 3 converter over a two-layer, partly-base64 envelope.
 */
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/webhooks/play")
@Slf4j
public class PlayWebhookController {

    private static final String BEARER_PREFIX = "Bearer ";

    private final PubSubTokenVerifier pubSubTokenVerifier;
    private final ObjectMapper objectMapper;
    private final SubscriptionWriter subscriptionWriter;

    @PostMapping
    public ResponseEntity<Void> handle(HttpServletRequest request,
                                        @RequestHeader(value = "Authorization", required = false) String authorization)
            throws IOException {
        String token = bearerToken(authorization);
        if (token == null || !pubSubTokenVerifier.isValid(token)) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        String eventId;
        PlaySubscriptionNotification subscriptionNotification;
        try {
            String body = new String(request.getInputStream().readAllBytes(), StandardCharsets.UTF_8);
            PubSubPushEnvelope envelope = objectMapper.readValue(body, PubSubPushEnvelope.class);
            eventId = envelope.message().messageId();
            byte[] decodedPayload = Base64.getDecoder().decode(envelope.message().data());
            subscriptionNotification = objectMapper.readValue(decodedPayload, PlayDeveloperNotification.class)
                    .subscriptionNotification();
        } catch (Exception e) {
            log.warn("Could not parse Play Pub/Sub push message", e);
            return ResponseEntity.badRequest().build();
        }

        if (subscriptionWriter.isAlreadyProcessed(SubscriptionProvider.PLAY_STORE, eventId)) {
            return ResponseEntity.ok().build();
        }

        if (apply(subscriptionNotification)) {
            subscriptionWriter.markProcessed(SubscriptionProvider.PLAY_STORE, eventId,
                    String.valueOf(subscriptionNotification.notificationType()));
        }
        return ResponseEntity.ok().build();
    }

    private boolean apply(PlaySubscriptionNotification notification) {
        if (notification == null) {
            // A test or one-time-product notification, not a subscription one — nothing to do.
            log.debug("Ignoring Play Pub/Sub push message with no subscriptionNotification");
            return false;
        }
        SubscriptionStatus status = PlayNotificationType.fromCode(notification.notificationType())
                .map(PlayWebhookController::statusFor)
                .orElse(null);
        if (status == null) {
            log.debug("Ignoring unhandled Play notification type code {}", notification.notificationType());
            return false;
        }
        // D-B6: the purchase token is the identity — same as the initial verify-purchase link (`64` Prompt 9).
        subscriptionWriter.markStatus(SubscriptionProvider.PLAY_STORE, notification.purchaseToken(), status);
        return true;
    }

    /** 64 §6.2's four handled types. */
    private static SubscriptionStatus statusFor(PlayNotificationType type) {
        return switch (type) {
            case SUBSCRIPTION_RENEWED -> SubscriptionStatus.ACTIVE;
            case SUBSCRIPTION_EXPIRED -> SubscriptionStatus.EXPIRED;
            case SUBSCRIPTION_IN_GRACE_PERIOD -> SubscriptionStatus.PAST_DUE;
            // Play has no distinct "refund" RTDN type; Google documents a revoke as
            // immediate access removal, most commonly refund-triggered — the closest
            // signal available, and a deliberate judgment call (64 §6.2).
            case SUBSCRIPTION_REVOKED -> SubscriptionStatus.REFUNDED;
            default -> null;
        };
    }

    private static String bearerToken(String authorizationHeader) {
        if (authorizationHeader == null || !authorizationHeader.startsWith(BEARER_PREFIX)) {
            return null;
        }
        return authorizationHeader.substring(BEARER_PREFIX.length());
    }
}

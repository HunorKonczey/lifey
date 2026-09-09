package com.lifey.billing.controller.webhook;

import com.apple.itunes.storekit.model.JWSTransactionDecodedPayload;
import com.apple.itunes.storekit.model.NotificationTypeV2;
import com.apple.itunes.storekit.model.ResponseBodyV2DecodedPayload;
import com.apple.itunes.storekit.verification.SignedDataVerifier;
import com.apple.itunes.storekit.verification.VerificationException;
import com.lifey.billing.dto.AppStoreServerNotificationRequest;
import com.lifey.billing.entity.SubscriptionProvider;
import com.lifey.billing.entity.SubscriptionStatus;
import com.lifey.billing.service.SubscriptionWriter;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;

/**
 * {@code POST /api/v1/webhooks/app-store} — App Store Server Notifications V2
 * (docs/landing_page/64-billing-backend-plan.md §6.2). Public (see {@code
 * SecurityConfig.PUBLIC_ENDPOINTS}), authenticated by the same JWS scheme as
 * a purchase's own transaction — no raw-body handling needed here, unlike
 * Stripe: the signature is over the {@code signedPayload} field's own
 * content, not the HTTP body bytes, so ordinary JSON binding is safe.
 *
 * <p>Every notification type not in the six handled here is acknowledged
 * with 200 and ignored, same as the Stripe webhook (`64` Prompt 5) — a 4xx
 * makes Apple retry forever.
 */
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/webhooks/app-store")
@Slf4j
public class AppStoreWebhookController {

    private final SignedDataVerifier signedDataVerifier;
    private final SubscriptionWriter subscriptionWriter;

    @PostMapping
    public ResponseEntity<Void> handle(@RequestBody AppStoreServerNotificationRequest request) {
        ResponseBodyV2DecodedPayload notification;
        try {
            notification = signedDataVerifier.verifyAndDecodeNotification(request.signedPayload());
        } catch (VerificationException e) {
            log.warn("App Store Server Notification signature verification failed", e);
            return ResponseEntity.badRequest().build();
        }

        String eventId = notification.getNotificationUUID();
        if (subscriptionWriter.isAlreadyProcessed(SubscriptionProvider.APP_STORE, eventId)) {
            return ResponseEntity.ok().build();
        }

        if (apply(notification)) {
            subscriptionWriter.markProcessed(SubscriptionProvider.APP_STORE, eventId,
                    notification.getNotificationType().name());
        }
        return ResponseEntity.ok().build();
    }

    private boolean apply(ResponseBodyV2DecodedPayload notification) {
        NotificationTypeV2 type = notification.getNotificationType();
        SubscriptionStatus status = statusFor(type);
        if (status == null) {
            log.debug("Ignoring unhandled App Store Server Notification type {}", type);
            return false;
        }

        JWSTransactionDecodedPayload transaction = decodeTransaction(notification);
        if (transaction == null) {
            return false;
        }

        if (type == NotificationTypeV2.DID_RENEW) {
            // A renewal is the one type worth a full state refresh — a new current_period_end,
            // not just a status flip. Plan/trial fields don't apply to store rows.
            Instant currentPeriodEnd = transaction.getExpiresDate() == null
                    ? null : Instant.ofEpochMilli(transaction.getExpiresDate());
            subscriptionWriter.syncSubscriptionState(SubscriptionProvider.APP_STORE, transaction.getOriginalTransactionId(),
                    status, null, currentPeriodEnd, null, false);
        } else {
            subscriptionWriter.markStatus(SubscriptionProvider.APP_STORE, transaction.getOriginalTransactionId(), status);
        }
        return true;
    }

    /**
     * 64 §6.2's six handled types. {@code REVOKE} is Family Sharing access
     * loss, not a refund — {@code REFUND} is its own separate type — so it
     * maps to {@code CANCELED}, not {@code REFUNDED}.
     */
    private static SubscriptionStatus statusFor(NotificationTypeV2 type) {
        return switch (type) {
            case DID_RENEW -> SubscriptionStatus.ACTIVE;
            case EXPIRED, GRACE_PERIOD_EXPIRED -> SubscriptionStatus.EXPIRED;
            case DID_FAIL_TO_RENEW -> SubscriptionStatus.PAST_DUE;
            case REFUND -> SubscriptionStatus.REFUNDED;
            case REVOKE -> SubscriptionStatus.CANCELED;
            default -> null;
        };
    }

    private JWSTransactionDecodedPayload decodeTransaction(ResponseBodyV2DecodedPayload notification) {
        String signedTransactionInfo = notification.getData() == null ? null : notification.getData().getSignedTransactionInfo();
        if (signedTransactionInfo == null) {
            log.warn("App Store Server Notification {} has no signedTransactionInfo, skipping", notification.getNotificationUUID());
            return null;
        }
        try {
            return signedDataVerifier.verifyAndDecodeTransaction(signedTransactionInfo);
        } catch (VerificationException e) {
            log.warn("Could not decode signedTransactionInfo for notification {}", notification.getNotificationUUID(), e);
            return null;
        }
    }
}

package com.lifey.billing.controller.webhook;

import com.apple.itunes.storekit.model.Environment;
import com.apple.itunes.storekit.verification.SignedDataVerifier;
import com.auth0.jwt.JWT;
import com.auth0.jwt.algorithms.Algorithm;
import com.lifey.billing.dto.AppStoreServerNotificationRequest;
import com.lifey.billing.entity.SubscriptionProvider;
import com.lifey.billing.entity.SubscriptionStatus;
import com.lifey.billing.service.AppleTestChain;
import com.lifey.billing.service.SubscriptionWriter;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import java.io.ByteArrayInputStream;
import java.security.interfaces.ECPrivateKey;
import java.time.Instant;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * The Prompt 10 *Verify* line in docs/landing_page/64-billing-backend-plan.md:
 * "fixture replay per notification type; duplicate delivery -> one write."
 * A plain unit test — the controller takes {@link AppStoreServerNotificationRequest}
 * as a normal {@code @RequestBody}, so no MockMvc/HTTP machinery is needed —
 * calling {@code handle(...)} directly is exactly what Spring would do after
 * JSON binding. Real StoreKit 2 JWS cryptography throughout, via the same
 * {@link AppleTestChain} `64` Prompt 8 built for {@code StoreBillingServiceImplTest}.
 */
@ExtendWith(MockitoExtension.class)
class AppStoreWebhookControllerTest {

    private static final String BUNDLE_ID = "com.lifey.app";
    private static final Instant NOW = Instant.parse("2026-06-15T09:00:00Z");
    private static final String ORIGINAL_TRANSACTION_ID = "2000000123456789";

    private static AppleTestChain.Chain chain;

    @Mock
    SubscriptionWriter subscriptionWriter;

    @BeforeAll
    static void generateChain() throws Exception {
        chain = AppleTestChain.generate();
    }

    private AppStoreWebhookController controller() {
        SignedDataVerifier verifier = new SignedDataVerifier(
                Set.of(new ByteArrayInputStream(uncheckedEncode())), BUNDLE_ID, 1234L, Environment.SANDBOX, false);
        return new AppStoreWebhookController(verifier, subscriptionWriter);
    }

    private static byte[] uncheckedEncode() {
        try {
            return chain.rootCertificate().getEncoded();
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    private String signedTransaction(long expiresDate) {
        String payload = """
                {
                  "originalTransactionId": "%s",
                  "transactionId": "2000000123456790",
                  "productId": "pro.monthly",
                  "bundleId": "%s",
                  "environment": "Sandbox",
                  "expiresDate": %d,
                  "signedDate": %d
                }
                """.formatted(ORIGINAL_TRANSACTION_ID, BUNDLE_ID, expiresDate, NOW.toEpochMilli());
        return JWT.create()
                .withHeader(Map.of("x5c", chain.x5c()))
                .withPayload(payload)
                .sign(Algorithm.ECDSA256((ECPrivateKey) chain.leafPrivateKey()));
    }

    private String signedNotification(String notificationType, String notificationUUID, String signedTransactionInfo) {
        String payload = """
                {
                  "notificationType": "%s",
                  "notificationUUID": "%s",
                  "version": "2.0",
                  "signedDate": %d,
                  "data": {
                    "bundleId": "%s",
                    "environment": "Sandbox",
                    "signedTransactionInfo": "%s"
                  }
                }
                """.formatted(notificationType, notificationUUID, NOW.toEpochMilli(), BUNDLE_ID, signedTransactionInfo);
        return JWT.create()
                .withHeader(Map.of("x5c", chain.x5c()))
                .withPayload(payload)
                .sign(Algorithm.ECDSA256((ECPrivateKey) chain.leafPrivateKey()));
    }

    // --- Fixture replay per handled notification type ------------------------------

    @Test
    void didRenew_syncsFullStateWithNewCurrentPeriodEnd() {
        long expiresDate = NOW.plusSeconds(86400).toEpochMilli();
        String jws = signedNotification("DID_RENEW", UUID.randomUUID().toString(), signedTransaction(expiresDate));

        ResponseEntity<Void> response = controller().handle(new AppStoreServerNotificationRequest(jws));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        verify(subscriptionWriter).syncSubscriptionState(eq(SubscriptionProvider.APP_STORE), eq(ORIGINAL_TRANSACTION_ID),
                eq(SubscriptionStatus.ACTIVE), eq(null), eq(Instant.ofEpochMilli(expiresDate)), eq(null), eq(false));
    }

    @ParameterizedTest
    @CsvSource({
            "EXPIRED, EXPIRED",
            "GRACE_PERIOD_EXPIRED, EXPIRED",
            "DID_FAIL_TO_RENEW, PAST_DUE",
            "REFUND, REFUNDED",
            "REVOKE, CANCELED",
    })
    void statusOnlyNotificationTypes_mapToTheExpectedStatus(String notificationType, SubscriptionStatus expectedStatus) {
        String jws = signedNotification(notificationType, UUID.randomUUID().toString(),
                signedTransaction(NOW.plusSeconds(86400).toEpochMilli()));

        ResponseEntity<Void> response = controller().handle(new AppStoreServerNotificationRequest(jws));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        verify(subscriptionWriter).markStatus(SubscriptionProvider.APP_STORE, ORIGINAL_TRANSACTION_ID, expectedStatus);
        verify(subscriptionWriter, never()).syncSubscriptionState(any(), any(), any(), any(), any(), any(), anyBoolean());
    }

    // --- Unhandled type -> no write -------------------------------------------------

    @Test
    void unhandledNotificationType_acknowledgesButWritesNothing() {
        String jws = signedNotification("SUBSCRIBED", UUID.randomUUID().toString(),
                signedTransaction(NOW.plusSeconds(86400).toEpochMilli()));

        ResponseEntity<Void> response = controller().handle(new AppStoreServerNotificationRequest(jws));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        verify(subscriptionWriter, never()).markStatus(any(), any(), any());
        verify(subscriptionWriter, never()).syncSubscriptionState(any(), any(), any(), any(), any(), any(), anyBoolean());
        verify(subscriptionWriter, never()).markProcessed(any(), any(), any());
    }

    // --- Duplicate delivery -> one write ---------------------------------------------

    @Test
    void duplicateDelivery_isNotAppliedTwice() {
        String notificationUUID = UUID.randomUUID().toString();
        String jws = signedNotification("REFUND", notificationUUID, signedTransaction(NOW.plusSeconds(86400).toEpochMilli()));
        when(subscriptionWriter.isAlreadyProcessed(SubscriptionProvider.APP_STORE, notificationUUID)).thenReturn(true);

        ResponseEntity<Void> response = controller().handle(new AppStoreServerNotificationRequest(jws));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        verify(subscriptionWriter, never()).markStatus(any(), any(), any());
        verify(subscriptionWriter, never()).markProcessed(any(), any(), any());
    }

    // --- Tampered signature -> 400 ----------------------------------------------------

    @Test
    void tamperedSignature_isRejectedWith400() {
        String jws = signedNotification("REFUND", UUID.randomUUID().toString(),
                signedTransaction(NOW.plusSeconds(86400).toEpochMilli()));
        int lastDot = jws.lastIndexOf('.');
        String signature = jws.substring(lastDot + 1);
        char flipped = signature.charAt(0) == 'A' ? 'B' : 'A';
        String tampered = jws.substring(0, lastDot + 1) + flipped + signature.substring(1);

        ResponseEntity<Void> response = controller().handle(new AppStoreServerNotificationRequest(tampered));

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        verify(subscriptionWriter, never()).markProcessed(any(), any(), any());
    }
}

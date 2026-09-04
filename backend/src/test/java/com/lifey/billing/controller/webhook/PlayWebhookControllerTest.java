package com.lifey.billing.controller.webhook;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.lifey.billing.PubSubTokenVerifier;
import com.lifey.billing.entity.SubscriptionProvider;
import com.lifey.billing.entity.SubscriptionStatus;
import com.lifey.billing.service.SubscriptionWriter;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.mock.web.MockHttpServletRequest;

import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * The Prompt 10 *Verify* line in docs/landing_page/64-billing-backend-plan.md:
 * "fixture replay per notification type; duplicate delivery -> one write" —
 * for the Play RTDN side. A plain unit test: {@link PlayWebhookController}
 * reads the raw body itself (see its javadoc), so a {@link MockHttpServletRequest}
 * with the body set is enough — no MockMvc/HTTP machinery needed.
 */
@ExtendWith(MockitoExtension.class)
class PlayWebhookControllerTest {

    private static final String PACKAGE_NAME = "com.lifey.app";
    private static final String PURCHASE_TOKEN = "play-purchase-token-abc";
    private static final String VALID_TOKEN = "valid-oidc-token";

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Mock
    PubSubTokenVerifier pubSubTokenVerifier;

    @Mock
    SubscriptionWriter subscriptionWriter;

    private PlayWebhookController controller() {
        return new PlayWebhookController(pubSubTokenVerifier, objectMapper, subscriptionWriter);
    }

    private void authorized() {
        when(pubSubTokenVerifier.isValid(VALID_TOKEN)).thenReturn(true);
    }

    private MockHttpServletRequest requestWithBody(String messageId, int notificationTypeCode) {
        String decodedPayload = """
                {
                  "packageName": "%s",
                  "eventTimeMillis": "1750000000000",
                  "subscriptionNotification": {
                    "notificationType": %d,
                    "purchaseToken": "%s",
                    "subscriptionId": "pro.monthly"
                  }
                }
                """.formatted(PACKAGE_NAME, notificationTypeCode, PURCHASE_TOKEN);
        String data = Base64.getEncoder().encodeToString(decodedPayload.getBytes(StandardCharsets.UTF_8));
        String envelope = """
                {
                  "message": {
                    "data": "%s",
                    "messageId": "%s",
                    "publishTime": "2026-06-15T09:00:00Z"
                  },
                  "subscription": "projects/lifey-prod/subscriptions/play-rtdn"
                }
                """.formatted(data, messageId);
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setContent(envelope.getBytes(StandardCharsets.UTF_8));
        return request;
    }

    // --- Missing/invalid OIDC token -> 401 -------------------------------------------

    @Test
    void missingAuthorizationHeader_isRejectedWith401() throws Exception {
        ResponseEntity<Void> response = controller().handle(requestWithBody(UUID.randomUUID().toString(), 2), null);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        verify(subscriptionWriter, never()).markStatus(any(), any(), any());
    }

    @Test
    void nonBearerAuthorizationHeader_isRejectedWith401() throws Exception {
        ResponseEntity<Void> response = controller().handle(requestWithBody(UUID.randomUUID().toString(), 2), "Basic abc123");

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void invalidOidcToken_isRejectedWith401() throws Exception {
        when(pubSubTokenVerifier.isValid("bad-token")).thenReturn(false);

        ResponseEntity<Void> response = controller().handle(requestWithBody(UUID.randomUUID().toString(), 2), "Bearer bad-token");

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        verify(subscriptionWriter, never()).markStatus(any(), any(), any());
    }

    // --- Malformed envelope -> 400 -----------------------------------------------------

    @Test
    void malformedEnvelope_isRejectedWith400() throws Exception {
        authorized();
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setContent("not-json".getBytes(StandardCharsets.UTF_8));

        ResponseEntity<Void> response = controller().handle(request, "Bearer " + VALID_TOKEN);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        verify(subscriptionWriter, never()).markProcessed(any(), any(), any());
    }

    // --- Fixture replay per handled notification type ---------------------------------

    @ParameterizedTest
    @CsvSource({
            "2, ACTIVE",     // SUBSCRIPTION_RENEWED
            "13, EXPIRED",   // SUBSCRIPTION_EXPIRED
            "6, PAST_DUE",   // SUBSCRIPTION_IN_GRACE_PERIOD
            "12, REFUNDED",  // SUBSCRIPTION_REVOKED
    })
    void handledNotificationTypes_mapToTheExpectedStatus(int typeCode, SubscriptionStatus expectedStatus) throws Exception {
        authorized();
        MockHttpServletRequest request = requestWithBody(UUID.randomUUID().toString(), typeCode);

        ResponseEntity<Void> response = controller().handle(request, "Bearer " + VALID_TOKEN);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        verify(subscriptionWriter).markStatus(SubscriptionProvider.PLAY_STORE, PURCHASE_TOKEN, expectedStatus);
    }

    // --- Unhandled type -> no write ----------------------------------------------------

    @Test
    void unhandledNotificationType_acknowledgesButWritesNothing() throws Exception {
        authorized();
        // SUBSCRIPTION_PURCHASED (4) — not one of `64` §6.2's four handled types.
        MockHttpServletRequest request = requestWithBody(UUID.randomUUID().toString(), 4);

        ResponseEntity<Void> response = controller().handle(request, "Bearer " + VALID_TOKEN);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        verify(subscriptionWriter, never()).markStatus(any(), any(), any());
        verify(subscriptionWriter, never()).markProcessed(any(), any(), any());
    }

    // --- Duplicate delivery -> one write ------------------------------------------------

    @Test
    void duplicateMessageId_isNotAppliedTwice() throws Exception {
        authorized();
        String messageId = UUID.randomUUID().toString();
        when(subscriptionWriter.isAlreadyProcessed(SubscriptionProvider.PLAY_STORE, messageId)).thenReturn(true);
        MockHttpServletRequest request = requestWithBody(messageId, 2);

        ResponseEntity<Void> response = controller().handle(request, "Bearer " + VALID_TOKEN);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        verify(subscriptionWriter, never()).markStatus(any(), any(), any());
        verify(subscriptionWriter, never()).markProcessed(any(), any(), any());
    }
}

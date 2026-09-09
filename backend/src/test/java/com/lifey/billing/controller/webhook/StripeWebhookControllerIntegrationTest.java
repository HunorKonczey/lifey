package com.lifey.billing.controller.webhook;

import com.lifey.billing.entity.Subscription;
import com.lifey.billing.entity.SubscriptionProvider;
import com.lifey.billing.entity.SubscriptionStatus;
import com.lifey.billing.entity.TrainerPlan;
import com.lifey.billing.repository.ProcessedBillingEventRepository;
import com.lifey.billing.repository.SubscriptionRepository;
import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.stripe.net.Webhook;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import java.time.Instant;
import java.util.HashSet;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * The Prompt 5 *Verify* line in docs/landing_page/64-billing-backend-plan.md:
 * "replay a captured event fixture twice → one state change; an unsigned
 * request → 400; an unknown event type → 200 and no write." Real signature
 * verification (via {@code Webhook.Signature.generateSignatureHeader}, the
 * Stripe SDK's own test helper), real DB, real dispatch.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
@TestPropertySource(properties = {
        "lifey.billing.stripe.webhook-secret=whsec_test_secret",
        "lifey.billing.stripe.pro-monthly-price-id=price_pro_monthly_test"
})
class StripeWebhookControllerIntegrationTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    private static final String WEBHOOK_SECRET = "whsec_test_secret";

    /**
     * Must match {@code com.stripe.ApiVersion.CURRENT} for this SDK version —
     * without it, {@code EventDataObjectDeserializer.getObject()} NPEs on a
     * null {@code api_version} rather than returning empty. A real Stripe
     * webhook always sets this; bump alongside the {@code stripe-java} version.
     */
    private static final String API_VERSION = "2026-08-26.dahlia";

    @Autowired
    MockMvc mockMvc;

    @Autowired
    UserRepository userRepository;

    @Autowired
    SubscriptionRepository subscriptionRepository;

    @Autowired
    ProcessedBillingEventRepository processedBillingEventRepository;

    @Test
    void unsignedRequest_isRejectedWith400() throws Exception {
        mockMvc.perform(post("/api/v1/webhooks/stripe")
                        .contentType("application/json")
                        .content(checkoutCompletedPayload("evt_unsigned", "cs_1", "1", "cus_1", "sub_1")))
                .andExpect(status().isBadRequest());
    }

    @Test
    void badlySignedRequest_isRejectedWith400() throws Exception {
        String payload = checkoutCompletedPayload("evt_bad_sig", "cs_1", "1", "cus_1", "sub_1");

        mockMvc.perform(post("/api/v1/webhooks/stripe")
                        .contentType("application/json")
                        .header("Stripe-Signature", "t=1,v1=not-a-real-signature")
                        .content(payload))
                .andExpect(status().isBadRequest());
    }

    @Test
    void unknownEventType_isAcknowledged_andWritesNothing() throws Exception {
        String eventId = "evt_unknown_" + System.nanoTime();
        String payload = """
                {
                  "id": "%s",
                  "object": "event",
                  "api_version": "%s",
                  "type": "payment_intent.succeeded",
                  "created": 1735689600,
                  "data": { "object": { "id": "pi_test_1", "object": "payment_intent" } }
                }
                """.formatted(eventId, API_VERSION);

        postSigned(payload).andExpect(status().isOk());

        assertThat(processedBillingEventRepository.existsByProviderAndEventId(SubscriptionProvider.STRIPE, eventId)).isFalse();
        assertThat(subscriptionRepository.findByProviderAndProviderCustomerId(SubscriptionProvider.STRIPE, "pi_test_1")).isEmpty();
    }

    @Test
    void checkoutSessionCompleted_replayedTwice_appliesOneStateChange() throws Exception {
        User trainer = saveUser("stripe-webhook-" + System.nanoTime() + "@example.com");
        String eventId = "evt_checkout_" + System.nanoTime();
        String customerId = "cus_" + System.nanoTime();
        String stripeSubscriptionId = "sub_" + System.nanoTime();
        String payload = checkoutCompletedPayload(eventId, "cs_" + System.nanoTime(),
                trainer.getId().toString(), customerId, stripeSubscriptionId);

        postSigned(payload).andExpect(status().isOk());

        Optional<Subscription> afterFirst = subscriptionRepository.findByUserIdAndProvider(trainer.getId(), SubscriptionProvider.STRIPE);
        assertThat(afterFirst).isPresent();
        assertThat(afterFirst.get().getProviderCustomerId()).isEqualTo(customerId);
        assertThat(afterFirst.get().getProviderSubscriptionId()).isEqualTo(stripeSubscriptionId);
        Long rowId = afterFirst.get().getId();

        // Replay the exact same event id.
        postSigned(payload).andExpect(status().isOk());

        List<Subscription> rows = subscriptionRepository.findByUserId(trainer.getId());
        assertThat(rows).hasSize(1);
        assertThat(rows.getFirst().getId()).isEqualTo(rowId);
        assertThat(processedBillingEventRepository.existsByProviderAndEventId(SubscriptionProvider.STRIPE, eventId)).isTrue();
    }

    @Test
    void checkoutSessionCompleted_forUnknownUser_isAcknowledged_andSkipsTheWrite() throws Exception {
        String eventId = "evt_checkout_unknown_user_" + System.nanoTime();
        String payload = checkoutCompletedPayload(eventId, "cs_" + System.nanoTime(), "999999999", "cus_x", "sub_x");

        postSigned(payload).andExpect(status().isOk());

        assertThat(subscriptionRepository.findByProviderAndProviderCustomerId(SubscriptionProvider.STRIPE, "cus_x")).isEmpty();
    }

    @Test
    void subscriptionUpdated_syncsStatusPlanAndPeriodEnd() throws Exception {
        User trainer = saveUser("stripe-webhook-sub-" + System.nanoTime() + "@example.com");
        String stripeSubscriptionId = "sub_" + System.nanoTime();
        Subscription existing = new Subscription();
        existing.setUser(trainer);
        existing.setProvider(SubscriptionProvider.STRIPE);
        existing.setStatus(SubscriptionStatus.ACTIVE);
        existing.setProviderCustomerId("cus_" + System.nanoTime());
        existing.setProviderSubscriptionId(stripeSubscriptionId);
        subscriptionRepository.save(existing);

        String eventId = "evt_sub_updated_" + System.nanoTime();
        String payload = """
                {
                  "id": "%s",
                  "object": "event",
                  "api_version": "%s",
                  "type": "customer.subscription.updated",
                  "created": 1735689600,
                  "data": {
                    "object": {
                      "id": "%s",
                      "object": "subscription",
                      "customer": "cus_doesnt_matter",
                      "status": "past_due",
                      "cancel_at_period_end": true,
                      "items": {
                        "object": "list",
                        "data": [
                          {
                            "id": "si_1",
                            "object": "subscription_item",
                            "current_period_end": 1738368000,
                            "price": { "id": "price_pro_monthly_test", "object": "price" }
                          }
                        ]
                      }
                    }
                  }
                }
                """.formatted(eventId, API_VERSION, stripeSubscriptionId);

        postSigned(payload).andExpect(status().isOk());

        Subscription updated = subscriptionRepository.findByProviderAndProviderSubscriptionId(SubscriptionProvider.STRIPE, stripeSubscriptionId)
                .orElseThrow();
        assertThat(updated.getStatus()).isEqualTo(SubscriptionStatus.PAST_DUE);
        assertThat(updated.getPlan()).isEqualTo(TrainerPlan.PRO);
        assertThat(updated.isCancelAtPeriodEnd()).isTrue();
        assertThat(updated.getCurrentPeriodEnd()).isEqualTo(Instant.ofEpochSecond(1738368000L));
    }

    @Test
    void subscriptionDeleted_marksCanceled() throws Exception {
        Subscription existing = seedActiveStripeSubscription();

        String eventId = "evt_sub_deleted_" + System.nanoTime();
        String payload = subscriptionEventPayload(eventId, "customer.subscription.deleted", existing.getProviderSubscriptionId());

        postSigned(payload).andExpect(status().isOk());

        assertThat(subscriptionRepository.findByProviderAndProviderSubscriptionId(SubscriptionProvider.STRIPE, existing.getProviderSubscriptionId())
                .orElseThrow().getStatus()).isEqualTo(SubscriptionStatus.CANCELED);
    }

    @Test
    void invoicePaymentFailed_marksPastDue() throws Exception {
        Subscription existing = seedActiveStripeSubscription();

        String eventId = "evt_invoice_failed_" + System.nanoTime();
        String payload = invoicePayload(eventId, "invoice.payment_failed", existing.getProviderSubscriptionId());

        postSigned(payload).andExpect(status().isOk());

        assertThat(subscriptionRepository.findByProviderAndProviderSubscriptionId(SubscriptionProvider.STRIPE, existing.getProviderSubscriptionId())
                .orElseThrow().getStatus()).isEqualTo(SubscriptionStatus.PAST_DUE);
    }

    @Test
    void invoicePaid_recoversFromPastDue() throws Exception {
        Subscription existing = seedActiveStripeSubscription();
        existing.setStatus(SubscriptionStatus.PAST_DUE);
        subscriptionRepository.save(existing);

        String eventId = "evt_invoice_paid_" + System.nanoTime();
        String payload = invoicePayload(eventId, "invoice.paid", existing.getProviderSubscriptionId());

        postSigned(payload).andExpect(status().isOk());

        assertThat(subscriptionRepository.findByProviderAndProviderSubscriptionId(SubscriptionProvider.STRIPE, existing.getProviderSubscriptionId())
                .orElseThrow().getStatus()).isEqualTo(SubscriptionStatus.ACTIVE);
    }

    @Test
    void chargeRefunded_marksRefundedByCustomerId() throws Exception {
        Subscription existing = seedActiveStripeSubscription();

        String eventId = "evt_charge_refunded_" + System.nanoTime();
        String payload = """
                {
                  "id": "%s",
                  "object": "event",
                  "api_version": "%s",
                  "type": "charge.refunded",
                  "created": 1735689600,
                  "data": {
                    "object": {
                      "id": "ch_1",
                      "object": "charge",
                      "customer": "%s",
                      "refunded": true
                    }
                  }
                }
                """.formatted(eventId, API_VERSION, existing.getProviderCustomerId());

        postSigned(payload).andExpect(status().isOk());

        assertThat(subscriptionRepository.findByProviderAndProviderSubscriptionId(SubscriptionProvider.STRIPE, existing.getProviderSubscriptionId())
                .orElseThrow().getStatus()).isEqualTo(SubscriptionStatus.REFUNDED);
    }

    private Subscription seedActiveStripeSubscription() {
        User trainer = saveUser("stripe-webhook-seed-" + System.nanoTime() + "@example.com");
        Subscription subscription = new Subscription();
        subscription.setUser(trainer);
        subscription.setProvider(SubscriptionProvider.STRIPE);
        subscription.setStatus(SubscriptionStatus.ACTIVE);
        subscription.setProviderCustomerId("cus_" + System.nanoTime());
        subscription.setProviderSubscriptionId("sub_" + System.nanoTime());
        return subscriptionRepository.save(subscription);
    }

    private String subscriptionEventPayload(String eventId, String eventType, String stripeSubscriptionId) {
        return """
                {
                  "id": "%s",
                  "object": "event",
                  "api_version": "%s",
                  "type": "%s",
                  "created": 1735689600,
                  "data": {
                    "object": {
                      "id": "%s",
                      "object": "subscription",
                      "customer": "cus_doesnt_matter",
                      "status": "canceled"
                    }
                  }
                }
                """.formatted(eventId, API_VERSION, eventType, stripeSubscriptionId);
    }

    private String invoicePayload(String eventId, String eventType, String stripeSubscriptionId) {
        return """
                {
                  "id": "%s",
                  "object": "event",
                  "api_version": "%s",
                  "type": "%s",
                  "created": 1735689600,
                  "data": {
                    "object": {
                      "id": "in_1",
                      "object": "invoice",
                      "customer": "cus_doesnt_matter",
                      "parent": {
                        "type": "subscription_details",
                        "subscription_details": { "subscription": "%s" }
                      }
                    }
                  }
                }
                """.formatted(eventId, API_VERSION, eventType, stripeSubscriptionId);
    }

    private String checkoutCompletedPayload(String eventId, String sessionId, String clientReferenceId,
                                             String customerId, String stripeSubscriptionId) {
        return """
                {
                  "id": "%s",
                  "object": "event",
                  "api_version": "%s",
                  "type": "checkout.session.completed",
                  "created": 1735689600,
                  "data": {
                    "object": {
                      "id": "%s",
                      "object": "checkout.session",
                      "client_reference_id": "%s",
                      "customer": "%s",
                      "subscription": "%s",
                      "mode": "subscription"
                    }
                  }
                }
                """.formatted(eventId, API_VERSION, sessionId, clientReferenceId, customerId, stripeSubscriptionId);
    }

    private org.springframework.test.web.servlet.ResultActions postSigned(String payload) throws Exception {
        String signature = Webhook.Signature.generateSignatureHeader(payload, WEBHOOK_SECRET);
        return mockMvc.perform(post("/api/v1/webhooks/stripe")
                .contentType("application/json")
                .header("Stripe-Signature", signature)
                .content(payload));
    }

    private User saveUser(String email) {
        User user = new User();
        user.setEmail(email);
        user.setPasswordHash("irrelevant");
        user.setCreatedAt(Instant.now());
        user.setRoles(new HashSet<>(List.of(Role.ROLE_USER, Role.ROLE_TRAINER)));
        return userRepository.save(user);
    }
}

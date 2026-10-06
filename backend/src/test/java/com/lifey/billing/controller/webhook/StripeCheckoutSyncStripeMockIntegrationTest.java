package com.lifey.billing.controller.webhook;

import com.lifey.billing.entity.Subscription;
import com.lifey.billing.entity.SubscriptionProvider;
import com.lifey.billing.entity.SubscriptionStatus;
import com.lifey.billing.entity.TrainerPlan;
import com.lifey.billing.repository.SubscriptionRepository;
import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.stripe.Stripe;
import com.stripe.net.Webhook;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

import java.time.Instant;
import java.util.HashSet;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Stripe does not deliver events in the order it made them: {@code customer.subscription.created} can arrive
 * before {@code checkout.session.completed}, finds no local row, and is skipped for good. So the checkout event
 * itself now reads the subscription from Stripe (here: stripe-mock) once it has linked it, and applies what it
 * finds. stripe-mock answers with its own fixture, so what is proven is that the read happens and its state
 * lands on the row - the trial row becomes the subscription Stripe describes - not any particular value.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
@TestPropertySource(properties = {
        "lifey.billing.stripe.webhook-secret=whsec_test_secret",
        "lifey.billing.stripe.secret-key=sk_test_stripemock"
})
class StripeCheckoutSyncStripeMockIntegrationTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    private static final int STRIPE_MOCK_HTTP_PORT = 12111;

    @Container
    static final GenericContainer<?> STRIPE_MOCK =
            new GenericContainer<>(DockerImageName.parse("stripe/stripe-mock:latest")).withExposedPorts(STRIPE_MOCK_HTTP_PORT);

    private static final String API_VERSION = "2026-08-26.dahlia";

    private static String originalApiBase;

    @BeforeAll
    static void pointSdkAtStripeMock() {
        originalApiBase = Stripe.getApiBase();
        Stripe.overrideApiBase("http://" + STRIPE_MOCK.getHost() + ":" + STRIPE_MOCK.getMappedPort(STRIPE_MOCK_HTTP_PORT));
    }

    @AfterAll
    static void restoreSdkApiBase() {
        Stripe.overrideApiBase(originalApiBase);
    }

    @Autowired
    MockMvc mockMvc;

    @Autowired
    UserRepository userRepository;

    @Autowired
    SubscriptionRepository subscriptionRepository;

    @Test
    void checkoutCompleted_linksTheTrialRow_andReadsTheSubscriptionFromStripe() throws Exception {
        User trainer = new User();
        trainer.setEmail("checkout-sync-" + System.nanoTime() + "@example.com");
        trainer.setPasswordHash("irrelevant");
        trainer.setCreatedAt(Instant.now());
        trainer.setRoles(new HashSet<>(List.of(Role.ROLE_USER, Role.ROLE_TRAINER)));
        trainer = userRepository.save(trainer);

        Subscription trial = new Subscription();
        trial.setUser(trainer);
        trial.setProvider(SubscriptionProvider.STRIPE);
        trial.setStatus(SubscriptionStatus.TRIALING);
        trial.setPlan(TrainerPlan.PRO);
        trial.setTrialEndsAt(Instant.now().plusSeconds(86_400));
        subscriptionRepository.save(trial);

        String subscriptionId = "sub_" + System.nanoTime();
        String eventId = "evt_checkout_sync_" + System.nanoTime();
        String payload = """
                {
                  "id": "%s",
                  "object": "event",
                  "api_version": "%s",
                  "type": "checkout.session.completed",
                  "created": 1735689600,
                  "data": { "object": { "id": "cs_1", "object": "checkout.session", "client_reference_id": "%d",
                                        "customer": "cus_sync", "subscription": "%s", "mode": "subscription" } }
                }
                """.formatted(eventId, API_VERSION, trainer.getId(), subscriptionId);

        String signature = Webhook.Signature.generateSignatureHeader(payload, "whsec_test_secret");
        mockMvc.perform(post("/api/v1/webhooks/stripe").contentType("application/json")
                .header("Stripe-Signature", signature).content(payload)).andExpect(status().isOk());

        Subscription row = subscriptionRepository.findByUserIdAndProvider(trainer.getId(), SubscriptionProvider.STRIPE).orElseThrow();
        assertThat(row.getProviderSubscriptionId()).isEqualTo(subscriptionId);
        // stripe-mock's fixture subscription is "active": the state came from Stripe, not from the trial row.
        assertThat(row.getStatus()).isEqualTo(SubscriptionStatus.ACTIVE);
    }
}

package com.lifey.billing.service;

import com.lifey.billing.dto.BillingInterval;
import com.lifey.billing.entity.Subscription;
import com.lifey.billing.entity.SubscriptionProvider;
import com.lifey.billing.entity.SubscriptionStatus;
import com.lifey.billing.entity.TrainerPlan;
import com.lifey.billing.repository.SubscriptionRepository;
import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.stripe.Stripe;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.test.context.TestPropertySource;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

import java.time.Instant;
import java.util.HashSet;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Closes half of the gap `64` Prompt 4's landed notes flagged and
 * `docs/landing_page/72` carries as B3: the checkout and portal calls had only
 * ever been exercised against {@code Mockito.mockStatic}, which proves the
 * params we <em>intended</em> to send and nothing about whether Stripe would
 * accept them.
 *
 * <p>This runs the real {@code stripe-java} SDK over real HTTP against
 * <a href="https://github.com/stripe/stripe-mock">stripe-mock</a>, Stripe's own
 * mock server, which validates each request against the published OpenAPI
 * spec. So a param Stripe renamed, a nesting we got wrong, or an SDK upgrade
 * that changes the wire shape fails here — in CI, with no account, no keys and
 * no network.
 *
 * <p><b>Exactly how much that is</b> — measured by probing the container
 * directly rather than assumed, because a test that cannot fail is worse than
 * no test:
 *
 * <ul>
 *   <li>a missing required param is rejected (empty body → 400);</li>
 *   <li>an illegal enum value is rejected ({@code mode=bogus} → 400,
 *       "value is not in enumeration");</li>
 *   <li><b>values are not checked at all</b> — a blank {@code price} on a line
 *       item is accepted. Verified by blanking
 *       {@code pro-monthly-price-id} below and watching all three tests still
 *       pass.</li>
 * </ul>
 *
 * <p>So this proves the <em>shape</em> of every call is legal, and nothing
 * about the values. What it therefore still cannot prove, and what keeps
 * `72` Prompt 12's manual run open: that our price ids exist, that the hosted
 * Checkout page renders the withdrawal-waiver consent checkbox, and that a
 * real subscription lifecycle behaves. Those need a real test-mode account —
 * see `72` §4's Prompt 12 runbook.
 */
@SpringBootTest
@Testcontainers
@TestPropertySource(properties = {
        "lifey.billing.enabled=true",
        // stripe-mock accepts any well-formed test key.
        "lifey.billing.stripe.secret-key=sk_test_stripemock",
        "lifey.billing.stripe.starter-monthly-price-id=price_starter_monthly",
        "lifey.billing.stripe.starter-yearly-price-id=price_starter_yearly",
        "lifey.billing.stripe.pro-monthly-price-id=price_pro_monthly",
        "lifey.billing.stripe.pro-yearly-price-id=price_pro_yearly",
        "lifey.billing.stripe.studio-monthly-price-id=price_studio_monthly",
        "lifey.billing.stripe.studio-yearly-price-id=price_studio_yearly"
})
class StripeBillingServiceStripeMockIntegrationTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    private static final int STRIPE_MOCK_HTTP_PORT = 12111;

    @Container
    static final GenericContainer<?> STRIPE_MOCK =
            new GenericContainer<>(DockerImageName.parse("stripe/stripe-mock:latest"))
                    .withExposedPorts(STRIPE_MOCK_HTTP_PORT);

    private static String originalApiBase;

    @BeforeAll
    static void pointSdkAtStripeMock() {
        originalApiBase = Stripe.getApiBase();
        Stripe.overrideApiBase("http://" + STRIPE_MOCK.getHost() + ":"
                + STRIPE_MOCK.getMappedPort(STRIPE_MOCK_HTTP_PORT));
    }

    @AfterAll
    static void restoreSdkApiBase() {
        // `overrideApiBase` is a static global on the SDK — leaving it pointed at
        // a dead container would break any later test that touches Stripe.
        Stripe.overrideApiBase(originalApiBase);
    }

    @Autowired
    StripeBillingService stripeBillingService;

    @Autowired
    UserRepository userRepository;

    @Autowired
    SubscriptionRepository subscriptionRepository;

    @Test
    void createCheckoutSession_isAcceptedByStripesOwnApiSchema() {
        User trainer = saveTrainer();

        String url = stripeBillingService.createCheckoutSession(
                trainer.getId(), TrainerPlan.PRO, BillingInterval.MONTHLY);

        // Reaching a URL at all means stripe-mock validated the whole
        // SessionCreateParams tree: subscription mode, client_reference_id,
        // automatic_tax, allow_promotion_codes, consent_collection with its
        // custom text, the line item, and customer_email.
        assertThat(url).isNotBlank();
    }

    @Test
    void createCheckoutSession_withAnExistingCustomer_isAlsoAccepted() {
        User trainer = saveTrainer();
        // The other branch of §5.1's customer reuse: `customer` instead of
        // `customer_email`. Stripe rejects sending both, which is exactly the
        // kind of mistake a mockStatic test cannot see.
        givenStripeCustomer(trainer, "cus_stripemock");

        String url = stripeBillingService.createCheckoutSession(
                trainer.getId(), TrainerPlan.STUDIO, BillingInterval.YEARLY);

        assertThat(url).isNotBlank();
    }

    @Test
    void createPortalSession_isAcceptedByStripesOwnApiSchema() {
        User trainer = saveTrainer();
        givenStripeCustomer(trainer, "cus_stripemock");

        String url = stripeBillingService.createPortalSession(trainer.getId());

        assertThat(url).isNotBlank();
    }

    private User saveTrainer() {
        User user = new User();
        user.setEmail("stripe-mock-" + System.nanoTime() + "@example.com");
        user.setPasswordHash("irrelevant");
        user.setCreatedAt(Instant.now());
        user.setRoles(new HashSet<>(List.of(Role.ROLE_USER, Role.ROLE_TRAINER)));
        return userRepository.save(user);
    }

    private void givenStripeCustomer(User trainer, String customerId) {
        Subscription subscription = new Subscription();
        subscription.setUser(trainer);
        subscription.setProvider(SubscriptionProvider.STRIPE);
        subscription.setStatus(SubscriptionStatus.ACTIVE);
        subscription.setPlan(TrainerPlan.PRO);
        subscription.setProviderCustomerId(customerId);
        subscriptionRepository.save(subscription);
    }
}

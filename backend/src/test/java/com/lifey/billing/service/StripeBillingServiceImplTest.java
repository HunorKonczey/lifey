package com.lifey.billing.service;

import com.lifey.billing.StripeProperties;
import com.lifey.billing.dto.BillingInterval;
import com.lifey.billing.entity.Subscription;
import com.lifey.billing.entity.SubscriptionProvider;
import com.lifey.billing.entity.TrainerPlan;
import com.lifey.billing.exception.StripeApiException;
import com.lifey.billing.repository.SubscriptionRepository;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.stripe.exception.ApiException;
import com.stripe.exception.StripeException;
import com.stripe.model.checkout.Session;
import com.stripe.net.RequestOptions;
import com.stripe.param.checkout.SessionCreateParams;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.MockedStatic;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mockStatic;
import static org.mockito.Mockito.when;

/**
 * "An integration test with the Stripe SDK stubbed, asserting client_reference_id
 * and the price id" — the Prompt 4 *Verify* line in
 * docs/landing_page/64-billing-backend-plan.md. Stubs the actual Stripe SDK
 * (`Session.create`) via {@link MockedStatic} rather than a hand-rolled
 * wrapper, so this proves what will actually be sent over the wire; real
 * end-to-end correctness still needs the manual run against Stripe test mode
 * the same *Verify* line calls for.
 */
@ExtendWith(MockitoExtension.class)
class StripeBillingServiceImplTest {

    private static final Long TRAINER_ID = 42L;

    private static final StripeProperties PROPERTIES = new StripeProperties(
            "sk_test_123",
            "whsec_test_123",
            "https://lifey.hu/admin/billing?checkout=success",
            "https://lifey.hu/admin/billing?checkout=cancel",
            "https://lifey.hu/admin/billing",
            "price_starter_monthly", "price_starter_yearly",
            "price_pro_monthly", "price_pro_yearly",
            "price_studio_monthly", "price_studio_yearly");

    @Mock
    UserRepository userRepository;

    @Mock
    SubscriptionRepository subscriptionRepository;

    private StripeBillingServiceImpl service() {
        return new StripeBillingServiceImpl(userRepository, subscriptionRepository, PROPERTIES);
    }

    private User trainer() {
        User user = new User();
        user.setId(TRAINER_ID);
        user.setEmail("trainer@example.com");
        return user;
    }

    // --- Checkout session ---------------------------------------------------------

    @Test
    void createCheckoutSession_setsClientReferenceIdAndPriceId_andReturnsTheSessionUrl() {
        when(userRepository.findById(TRAINER_ID)).thenReturn(Optional.of(trainer()));
        when(subscriptionRepository.findByUserIdAndProvider(TRAINER_ID, SubscriptionProvider.STRIPE))
                .thenReturn(Optional.empty());

        Session fakeSession = new Session();
        fakeSession.setUrl("https://checkout.stripe.com/c/pay/cs_test_abc");

        try (MockedStatic<Session> mocked = mockStatic(Session.class)) {
            ArgumentCaptor<SessionCreateParams> paramsCaptor = ArgumentCaptor.forClass(SessionCreateParams.class);
            mocked.when(() -> Session.create(paramsCaptor.capture(), any(RequestOptions.class))).thenReturn(fakeSession);

            String url = service().createCheckoutSession(TRAINER_ID, TrainerPlan.PRO, BillingInterval.MONTHLY);

            assertThat(url).isEqualTo("https://checkout.stripe.com/c/pay/cs_test_abc");
            SessionCreateParams params = paramsCaptor.getValue();
            assertThat(params.getClientReferenceId()).isEqualTo(TRAINER_ID.toString());
            assertThat(params.getMode()).isEqualTo(SessionCreateParams.Mode.SUBSCRIPTION);
            assertThat(params.getLineItems()).singleElement()
                    .satisfies(item -> assertThat(item.getPrice()).isEqualTo("price_pro_monthly"));
            assertThat(params.getCustomerEmail()).isEqualTo("trainer@example.com");
            assertThat(params.getCustomer()).isNull();
        }
    }

    @Test
    void createCheckoutSession_reusesTheExistingStripeCustomer_ratherThanTheEmail() {
        when(userRepository.findById(TRAINER_ID)).thenReturn(Optional.of(trainer()));
        Subscription existing = new Subscription();
        existing.setProvider(SubscriptionProvider.STRIPE);
        existing.setProviderCustomerId("cus_existing_123");
        when(subscriptionRepository.findByUserIdAndProvider(TRAINER_ID, SubscriptionProvider.STRIPE))
                .thenReturn(Optional.of(existing));

        Session fakeSession = new Session();
        fakeSession.setUrl("https://checkout.stripe.com/c/pay/cs_test_def");

        try (MockedStatic<Session> mocked = mockStatic(Session.class)) {
            ArgumentCaptor<SessionCreateParams> paramsCaptor = ArgumentCaptor.forClass(SessionCreateParams.class);
            mocked.when(() -> Session.create(paramsCaptor.capture(), any(RequestOptions.class))).thenReturn(fakeSession);

            service().createCheckoutSession(TRAINER_ID, TrainerPlan.STARTER, BillingInterval.YEARLY);

            SessionCreateParams params = paramsCaptor.getValue();
            assertThat(params.getCustomer()).isEqualTo("cus_existing_123");
            assertThat(params.getCustomerEmail()).isNull();
            assertThat(params.getLineItems()).singleElement()
                    .satisfies(item -> assertThat(item.getPrice()).isEqualTo("price_starter_yearly"));
        }
    }

    @Test
    void createCheckoutSession_unknownTrainer_throwsResourceNotFound() {
        when(userRepository.findById(TRAINER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service().createCheckoutSession(TRAINER_ID, TrainerPlan.PRO, BillingInterval.MONTHLY))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void createCheckoutSession_stripeFailure_isWrappedAsStripeApiException() {
        when(userRepository.findById(TRAINER_ID)).thenReturn(Optional.of(trainer()));
        when(subscriptionRepository.findByUserIdAndProvider(TRAINER_ID, SubscriptionProvider.STRIPE))
                .thenReturn(Optional.empty());

        try (MockedStatic<Session> mocked = mockStatic(Session.class)) {
            StripeException stripeException = new ApiException("boom", null, null, null, null);
            mocked.when(() -> Session.create(any(SessionCreateParams.class), any(RequestOptions.class)))
                    .thenThrow(stripeException);

            assertThatThrownBy(() -> service().createCheckoutSession(TRAINER_ID, TrainerPlan.PRO, BillingInterval.MONTHLY))
                    .isInstanceOf(StripeApiException.class)
                    .hasCause(stripeException);
        }
    }

    // --- Portal session ------------------------------------------------------------

    @Test
    void createPortalSession_usesTheExistingCustomerId_andReturnsTheSessionUrl() {
        Subscription existing = new Subscription();
        existing.setProvider(SubscriptionProvider.STRIPE);
        existing.setProviderCustomerId("cus_existing_123");
        when(subscriptionRepository.findByUserIdAndProvider(TRAINER_ID, SubscriptionProvider.STRIPE))
                .thenReturn(Optional.of(existing));

        com.stripe.model.billingportal.Session fakeSession = new com.stripe.model.billingportal.Session();
        fakeSession.setUrl("https://billing.stripe.com/p/session/xyz");

        try (MockedStatic<com.stripe.model.billingportal.Session> mocked =
                     mockStatic(com.stripe.model.billingportal.Session.class)) {
            ArgumentCaptor<com.stripe.param.billingportal.SessionCreateParams> paramsCaptor =
                    ArgumentCaptor.forClass(com.stripe.param.billingportal.SessionCreateParams.class);
            mocked.when(() -> com.stripe.model.billingportal.Session.create(paramsCaptor.capture(), any(RequestOptions.class)))
                    .thenReturn(fakeSession);

            String url = service().createPortalSession(TRAINER_ID);

            assertThat(url).isEqualTo("https://billing.stripe.com/p/session/xyz");
            assertThat(paramsCaptor.getValue().getCustomer()).isEqualTo("cus_existing_123");
            assertThat(paramsCaptor.getValue().getReturnUrl()).isEqualTo("https://lifey.hu/admin/billing");
        }
    }

    @Test
    void createPortalSession_noLinkedCustomerYet_throwsResourceNotFound() {
        when(subscriptionRepository.findByUserIdAndProvider(TRAINER_ID, SubscriptionProvider.STRIPE))
                .thenReturn(Optional.empty());

        assertThatThrownBy(() -> service().createPortalSession(TRAINER_ID))
                .isInstanceOf(ResourceNotFoundException.class);
    }
}

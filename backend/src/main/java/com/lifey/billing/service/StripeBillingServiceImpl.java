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
import com.stripe.exception.StripeException;
import com.stripe.model.checkout.Session;
import com.stripe.net.RequestOptions;
import com.stripe.param.checkout.SessionCreateParams;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;

/**
 * The Stripe Checkout + billing-portal adapter (docs/landing_page/64-billing-backend-plan.md
 * §5.1–5.2). No webhook yet (`64` Prompt 5) — a session is created and its URL
 * handed back; entitlement never changes here (D-B5).
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class StripeBillingServiceImpl implements StripeBillingService {

    private static final String WITHDRAWAL_WAIVER_MESSAGE =
            "I request immediate performance and waive my 14-day right of withdrawal for this digital service.";

    private final UserRepository userRepository;
    private final SubscriptionRepository subscriptionRepository;
    private final StripeProperties stripeProperties;

    @Override
    public String createCheckoutSession(Long trainerId, TrainerPlan plan, BillingInterval interval) {
        User trainer = userRepository.findById(trainerId)
                .orElseThrow(() -> new ResourceNotFoundException("Trainer not found: " + trainerId));

        SessionCreateParams.Builder params = SessionCreateParams.builder()
                .setMode(SessionCreateParams.Mode.SUBSCRIPTION)
                .setClientReferenceId(trainerId.toString())
                .setSuccessUrl(stripeProperties.successUrl())
                .setCancelUrl(stripeProperties.cancelUrl())
                .setAllowPromotionCodes(true)
                .setAutomaticTax(SessionCreateParams.AutomaticTax.builder().setEnabled(true).build())
                // The EU 14-day withdrawal-right waiver checkbox (63 §5) — a real consent
                // field, not just fine print, so Checkout actually collects it.
                .setConsentCollection(SessionCreateParams.ConsentCollection.builder()
                        .setTermsOfService(SessionCreateParams.ConsentCollection.TermsOfService.REQUIRED)
                        .build())
                .setCustomText(SessionCreateParams.CustomText.builder()
                        .setTermsOfServiceAcceptance(SessionCreateParams.CustomText.TermsOfServiceAcceptance.builder()
                                .setMessage(WITHDRAWAL_WAIVER_MESSAGE)
                                .build())
                        .build())
                .addLineItem(SessionCreateParams.LineItem.builder()
                        .setPrice(stripeProperties.priceId(plan, interval))
                        .setQuantity(1L)
                        .build());

        // Reuse the trainer's existing Stripe Customer if the webhook (Prompt 5) has
        // already mirrored one, rather than letting Stripe mint a duplicate (§5.1).
        existingStripeCustomerId(trainerId)
                .ifPresentOrElse(params::setCustomer, () -> params.setCustomerEmail(trainer.getEmail()));

        try {
            Session session = Session.create(params.build(), requestOptions());
            return session.getUrl();
        } catch (StripeException e) {
            throw new StripeApiException("Failed to create Stripe checkout session for trainer " + trainerId, e);
        }
    }

    @Override
    public String createPortalSession(Long trainerId) {
        String customerId = existingStripeCustomerId(trainerId)
                .orElseThrow(() -> new ResourceNotFoundException("No linked Stripe customer for trainer: " + trainerId));

        com.stripe.param.billingportal.SessionCreateParams params = com.stripe.param.billingportal.SessionCreateParams.builder()
                .setCustomer(customerId)
                .setReturnUrl(stripeProperties.portalReturnUrl())
                .build();

        try {
            com.stripe.model.billingportal.Session session =
                    com.stripe.model.billingportal.Session.create(params, requestOptions());
            return session.getUrl();
        } catch (StripeException e) {
            throw new StripeApiException("Failed to create Stripe portal session for trainer " + trainerId, e);
        }
    }

    private Optional<String> existingStripeCustomerId(Long trainerId) {
        return subscriptionRepository.findByUserIdAndProvider(trainerId, SubscriptionProvider.STRIPE)
                .map(Subscription::getProviderCustomerId)
                .filter(id -> id != null && !id.isBlank());
    }

    private RequestOptions requestOptions() {
        return RequestOptions.builder().setApiKey(stripeProperties.secretKey()).build();
    }
}

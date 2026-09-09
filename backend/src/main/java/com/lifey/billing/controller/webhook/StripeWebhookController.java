package com.lifey.billing.controller.webhook;

import com.lifey.billing.StripeProperties;
import com.lifey.billing.entity.SubscriptionProvider;
import com.lifey.billing.entity.SubscriptionStatus;
import com.lifey.billing.entity.TrainerPlan;
import com.lifey.billing.service.SubscriptionWriter;
import com.stripe.exception.EventDataObjectDeserializationException;
import com.stripe.exception.SignatureVerificationException;
import com.stripe.model.Charge;
import com.stripe.model.Event;
import com.stripe.model.Invoice;
import com.stripe.model.StripeObject;
import com.stripe.model.SubscriptionItem;
import com.stripe.model.checkout.Session;
import com.stripe.net.Webhook;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.List;

/**
 * {@code POST /api/v1/webhooks/stripe} (docs/landing_page/64-billing-backend-plan.md
 * §5.3) — public (see {@code SecurityConfig.PUBLIC_ENDPOINTS}), authenticated
 * by Stripe's own signature header instead of a JWT. Reads the raw body
 * directly off the request rather than via {@code @RequestBody}, since the
 * signature is computed over the exact bytes Stripe sent — a JSON
 * message-converter round trip would not reliably preserve that.
 *
 * <p>Every event type not in the six handled here is acknowledged with 200 and
 * ignored (a 4xx makes Stripe retry forever); the webhook only ever *records*
 * what Stripe reports, never trusts the checkout success redirect (D-B5).
 */
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/webhooks/stripe")
@Slf4j
public class StripeWebhookController {

    private static final List<String> TERMINAL_STRIPE_STATUSES = List.of("canceled", "unpaid", "incomplete_expired");

    private final StripeProperties stripeProperties;
    private final SubscriptionWriter subscriptionWriter;

    @PostMapping
    public ResponseEntity<Void> handle(HttpServletRequest request) throws IOException {
        String signature = request.getHeader("Stripe-Signature");
        if (signature == null || signature.isBlank()) {
            return ResponseEntity.badRequest().build();
        }

        String payload = new String(request.getInputStream().readAllBytes(), StandardCharsets.UTF_8);
        Event event;
        try {
            event = Webhook.constructEvent(payload, signature, stripeProperties.webhookSecret());
        } catch (SignatureVerificationException e) {
            log.warn("Stripe webhook signature verification failed", e);
            return ResponseEntity.badRequest().build();
        }

        if (subscriptionWriter.isAlreadyProcessed(SubscriptionProvider.STRIPE, event.getId())) {
            return ResponseEntity.ok().build();
        }

        // Only one of the six handled types reaches the idempotency ledger (§5.4) — an
        // unhandled type is acknowledged but leaves no trace, matching Prompt 5's own
        // *Verify* line ("an unknown event type -> 200 and no write").
        if (dispatch(event)) {
            subscriptionWriter.markProcessed(SubscriptionProvider.STRIPE, event.getId(), event.getType());
        }
        return ResponseEntity.ok().build();
    }

    private boolean dispatch(Event event) {
        return switch (event.getType()) {
            case "checkout.session.completed" -> {
                handleCheckoutCompleted(event);
                yield true;
            }
            case "customer.subscription.created", "customer.subscription.updated" -> {
                handleSubscriptionUpsert(event);
                yield true;
            }
            case "customer.subscription.deleted" -> {
                handleSubscriptionDeleted(event);
                yield true;
            }
            case "invoice.paid" -> {
                handleInvoicePaid(event);
                yield true;
            }
            case "invoice.payment_failed" -> {
                handleInvoicePaymentFailed(event);
                yield true;
            }
            case "charge.refunded" -> {
                handleChargeRefunded(event);
                yield true;
            }
            default -> {
                log.debug("Ignoring unhandled Stripe event type {}", event.getType());
                yield false;
            }
        };
    }

    private void handleCheckoutCompleted(Event event) {
        Session session = (Session) dataObject(event);
        if (session == null) {
            return;
        }
        String clientReferenceId = session.getClientReferenceId();
        Long userId = parseUserId(clientReferenceId, session.getId());
        if (userId == null) {
            return;
        }
        subscriptionWriter.linkCheckoutSession(userId, SubscriptionProvider.STRIPE, session.getCustomer(), session.getSubscription());
    }

    private void handleSubscriptionUpsert(Event event) {
        com.stripe.model.Subscription subscription = (com.stripe.model.Subscription) dataObject(event);
        if (subscription == null) {
            return;
        }
        SubscriptionStatus status = mapStatus(subscription.getStatus());
        if (status == null) {
            log.debug("Ignoring Stripe subscription {} in status {}", subscription.getId(), subscription.getStatus());
            return;
        }

        SubscriptionItem item = subscription.getItems() == null || subscription.getItems().getData().isEmpty()
                ? null : subscription.getItems().getData().getFirst();
        TrainerPlan plan = item == null ? null : stripeProperties.planFor(item.getPrice().getId()).orElse(null);
        Instant currentPeriodEnd = item == null || item.getCurrentPeriodEnd() == null
                ? null : Instant.ofEpochSecond(item.getCurrentPeriodEnd());
        Instant trialEndsAt = subscription.getTrialEnd() == null ? null : Instant.ofEpochSecond(subscription.getTrialEnd());
        boolean cancelAtPeriodEnd = Boolean.TRUE.equals(subscription.getCancelAtPeriodEnd());

        subscriptionWriter.syncSubscriptionState(SubscriptionProvider.STRIPE, subscription.getId(),
                status, plan, currentPeriodEnd, trialEndsAt, cancelAtPeriodEnd);
    }

    private void handleSubscriptionDeleted(Event event) {
        com.stripe.model.Subscription subscription = (com.stripe.model.Subscription) dataObject(event);
        if (subscription == null) {
            return;
        }
        subscriptionWriter.markStatus(SubscriptionProvider.STRIPE, subscription.getId(), SubscriptionStatus.CANCELED);
    }

    private void handleInvoicePaid(Event event) {
        Invoice invoice = (Invoice) dataObject(event);
        String subscriptionId = subscriptionId(invoice);
        if (subscriptionId == null) {
            return;
        }
        // Recovers from PAST_DUE (dunning); harmless to also fire on the very first invoice.
        subscriptionWriter.markStatus(SubscriptionProvider.STRIPE, subscriptionId, SubscriptionStatus.ACTIVE);
    }

    private void handleInvoicePaymentFailed(Event event) {
        Invoice invoice = (Invoice) dataObject(event);
        String subscriptionId = subscriptionId(invoice);
        if (subscriptionId == null) {
            return;
        }
        subscriptionWriter.markStatus(SubscriptionProvider.STRIPE, subscriptionId, SubscriptionStatus.PAST_DUE);
    }

    private void handleChargeRefunded(Event event) {
        Charge charge = (Charge) dataObject(event);
        if (charge == null || charge.getCustomer() == null) {
            return;
        }
        subscriptionWriter.markRefundedByCustomerId(SubscriptionProvider.STRIPE, charge.getCustomer());
    }

    private static String subscriptionId(Invoice invoice) {
        if (invoice == null || invoice.getParent() == null || invoice.getParent().getSubscriptionDetails() == null) {
            return null;
        }
        return invoice.getParent().getSubscriptionDetails().getSubscription();
    }

    private static Long parseUserId(String clientReferenceId, String sessionId) {
        if (clientReferenceId == null) {
            log.warn("Stripe checkout.session.completed {} has no client_reference_id, skipping", sessionId);
            return null;
        }
        try {
            return Long.valueOf(clientReferenceId);
        } catch (NumberFormatException _) {
            log.warn("Stripe checkout.session.completed {} has a non-numeric client_reference_id '{}', skipping",
                    sessionId, clientReferenceId);
            return null;
        }
    }

    /** Stripe's own status strings (active/trialing/past_due/canceled/unpaid/incomplete/incomplete_expired/paused). */
    private static SubscriptionStatus mapStatus(String stripeStatus) {
        if (stripeStatus == null) {
            return null;
        }
        return switch (stripeStatus) {
            case "trialing" -> SubscriptionStatus.TRIALING;
            case "active" -> SubscriptionStatus.ACTIVE;
            case "past_due" -> SubscriptionStatus.PAST_DUE;
            default -> TERMINAL_STRIPE_STATUSES.contains(stripeStatus) ? SubscriptionStatus.CANCELED : null;
        };
    }

    /** Falls back to {@code deserializeUnsafe} for an event recorded under a different API version than this SDK expects. */
    private static StripeObject dataObject(Event event) {
        return event.getDataObjectDeserializer().getObject().orElseGet(() -> {
            try {
                return event.getDataObjectDeserializer().deserializeUnsafe();
            } catch (EventDataObjectDeserializationException e) {
                log.warn("Could not deserialize Stripe event {} ({})", event.getId(), event.getType(), e);
                return null;
            }
        });
    }
}

package com.lifey.billing.service;

import com.apple.itunes.storekit.client.AppStoreServerAPIClient;
import com.apple.itunes.storekit.model.JWSTransactionDecodedPayload;
import com.apple.itunes.storekit.verification.SignedDataVerifier;
import com.apple.itunes.storekit.verification.VerificationException;
import com.google.api.services.androidpublisher.model.SubscriptionPurchaseLineItem;
import com.google.api.services.androidpublisher.model.SubscriptionPurchaseV2;
import com.lifey.billing.AppleProperties;
import com.lifey.billing.GoogleProperties;
import com.lifey.billing.dto.EntitlementResponse;
import com.lifey.billing.dto.StorePurchaseRequest;
import com.lifey.billing.entity.Subscription;
import com.lifey.billing.entity.SubscriptionProvider;
import com.lifey.billing.entity.SubscriptionStatus;
import com.lifey.billing.exception.InvalidReceiptException;
import com.lifey.billing.exception.SubscriptionAlreadyLinkedException;
import com.lifey.billing.repository.SubscriptionRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.io.IOException;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.Set;

/**
 * Store purchase verification (docs/landing_page/64-billing-backend-plan.md
 * §6.1). iOS (`64` Prompt 8) verifies StoreKit 2's signed JWS locally first,
 * then best-effort confirms with the App Store Server API — "local
 * verification first means a working purchase even during an Apple API
 * blip." Android (`64` Prompt 9) has no local check at all: {@code
 * purchases.subscriptionsv2.get} on the Play Developer API *is* the
 * verification, so unlike Apple's confirmation step, a failure here must
 * never be swallowed.
 */
@Service
@RequiredArgsConstructor
@Transactional
@Slf4j
public class StoreBillingServiceImpl implements StoreBillingService {

    /** 64 §6.1: which Play subscription states still let the entitlement resolver see this as active/near-active. */
    private static final Set<String> PLAY_ACTIVE_STATES = Set.of("SUBSCRIPTION_STATE_ACTIVE", "SUBSCRIPTION_STATE_IN_GRACE_PERIOD");
    private static final Set<String> PLAY_PAST_DUE_STATES = Set.of("SUBSCRIPTION_STATE_ON_HOLD", "SUBSCRIPTION_STATE_PAUSED");
    private static final String PLAY_ACKNOWLEDGED = "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED";

    private final SignedDataVerifier signedDataVerifier;
    private final AppleProperties appleProperties;
    private final PlayPurchaseClient playPurchaseClient;
    private final GoogleProperties googleProperties;
    private final SubscriptionRepository subscriptionRepository;
    private final SubscriptionWriter subscriptionWriter;
    private final EntitlementService entitlementService;
    private final Clock clock;

    @Override
    public EntitlementResponse verifyPurchase(Long userId, StorePurchaseRequest request) {
        return switch (request.platform()) {
            case IOS -> verifyIosPurchase(userId, request);
            case ANDROID -> verifyAndroidPurchase(userId, request);
        };
    }

    // --- iOS (64 Prompt 8) -----------------------------------------------------------

    private EntitlementResponse verifyIosPurchase(Long userId, StorePurchaseRequest request) {
        JWSTransactionDecodedPayload transaction = verifyAndDecode(request.purchaseToken());

        String originalTransactionId = transaction.getOriginalTransactionId();
        rejectIfLinkedToAnotherUser(SubscriptionProvider.APP_STORE, originalTransactionId, userId);

        confirmWithAppStoreServerApi(transaction.getTransactionId());

        Instant currentPeriodEnd = transaction.getExpiresDate() == null
                ? null : Instant.ofEpochMilli(transaction.getExpiresDate());
        subscriptionWriter.linkStorePurchase(userId, SubscriptionProvider.APP_STORE, originalTransactionId,
                mapAppleStatus(transaction), currentPeriodEnd);

        return entitlementService.resolve(userId);
    }

    private JWSTransactionDecodedPayload verifyAndDecode(String purchaseToken) {
        try {
            return signedDataVerifier.verifyAndDecodeTransaction(purchaseToken);
        } catch (VerificationException e) {
            throw new InvalidReceiptException("Could not verify the App Store transaction", e);
        }
    }

    /**
     * A blip here — including no Apple credentials configured at all — must
     * never block a purchase already proven genuine by local verification
     * above, so every failure is caught, logged, and swallowed rather than
     * surfaced to the caller.
     */
    private void confirmWithAppStoreServerApi(String transactionId) {
        try {
            AppStoreServerAPIClient client = new AppStoreServerAPIClient(appleProperties.privateKey(),
                    appleProperties.keyId(), appleProperties.issuerId(), appleProperties.bundleId(),
                    appleProperties.environment());
            client.getTransactionInfo(transactionId);
        } catch (Exception e) {
            log.warn("Could not confirm transaction {} with the App Store Server API, "
                    + "proceeding on local verification alone", transactionId, e);
        }
    }

    private SubscriptionStatus mapAppleStatus(JWSTransactionDecodedPayload transaction) {
        if (transaction.getRevocationDate() != null) {
            return SubscriptionStatus.REFUNDED;
        }
        Long expiresDate = transaction.getExpiresDate();
        if (expiresDate != null && expiresDate < clock.millis()) {
            return SubscriptionStatus.EXPIRED;
        }
        return SubscriptionStatus.ACTIVE;
    }

    // --- Android (64 Prompt 9) -----------------------------------------------------------

    private EntitlementResponse verifyAndroidPurchase(Long userId, StorePurchaseRequest request) {
        SubscriptionPurchaseV2 purchase = fetchPlaySubscription(request.purchaseToken());

        // D-B6: the purchase token itself is the identity — Play never hands back a
        // separate "subscription id" distinct from the token that was verified.
        String providerSubscriptionId = request.purchaseToken();
        rejectIfLinkedToAnotherUser(SubscriptionProvider.PLAY_STORE, providerSubscriptionId, userId);

        acknowledgeIfNeeded(request, purchase);

        subscriptionWriter.linkStorePurchase(userId, SubscriptionProvider.PLAY_STORE, providerSubscriptionId,
                mapPlayStatus(purchase.getSubscriptionState()), expiryOf(purchase));

        return entitlementService.resolve(userId);
    }

    private SubscriptionPurchaseV2 fetchPlaySubscription(String purchaseToken) {
        try {
            return playPurchaseClient.getSubscription(googleProperties.packageName(), purchaseToken);
        } catch (IOException e) {
            throw new InvalidReceiptException("Could not verify the Play purchase", e);
        }
    }

    /**
     * Unlike Apple's confirmation step, a failure here is never swallowed: an
     * unacknowledged Play purchase is auto-refunded after 3 days (64 §6.1), a
     * silent revenue loss that must surface as a failed request, not a quiet log line.
     */
    private void acknowledgeIfNeeded(StorePurchaseRequest request, SubscriptionPurchaseV2 purchase) {
        if (PLAY_ACKNOWLEDGED.equals(purchase.getAcknowledgementState())) {
            return;
        }
        try {
            playPurchaseClient.acknowledge(googleProperties.packageName(), request.productId(), request.purchaseToken());
        } catch (IOException e) {
            throw new InvalidReceiptException("Could not acknowledge the Play purchase", e);
        }
    }

    private SubscriptionStatus mapPlayStatus(String subscriptionState) {
        if (PLAY_ACTIVE_STATES.contains(subscriptionState)) {
            return SubscriptionStatus.ACTIVE;
        }
        if (PLAY_PAST_DUE_STATES.contains(subscriptionState)) {
            return SubscriptionStatus.PAST_DUE;
        }
        if ("SUBSCRIPTION_STATE_CANCELED".equals(subscriptionState)) {
            return SubscriptionStatus.CANCELED;
        }
        // SUBSCRIPTION_STATE_EXPIRED, _PENDING, _PENDING_PURCHASE_CANCELED, _UNSPECIFIED, null: no entitlement.
        return SubscriptionStatus.EXPIRED;
    }

    private Instant expiryOf(SubscriptionPurchaseV2 purchase) {
        List<SubscriptionPurchaseLineItem> lineItems = purchase.getLineItems();
        if (lineItems == null || lineItems.isEmpty() || lineItems.getFirst().getExpiryTime() == null) {
            return null;
        }
        return Instant.parse(lineItems.getFirst().getExpiryTime());
    }

    // --- Shared -----------------------------------------------------------------------

    private void rejectIfLinkedToAnotherUser(SubscriptionProvider provider, String providerSubscriptionId, Long userId) {
        Optional<Subscription> existing = subscriptionRepository.findByProviderAndProviderSubscriptionId(
                provider, providerSubscriptionId);
        if (existing.isPresent() && !existing.get().getUser().getId().equals(userId)) {
            throw new SubscriptionAlreadyLinkedException(
                    "This subscription is already linked to another account");
        }
    }
}

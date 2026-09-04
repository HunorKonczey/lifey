package com.lifey.billing.service;

import com.apple.itunes.storekit.model.Environment;
import com.apple.itunes.storekit.verification.SignedDataVerifier;
import com.auth0.jwt.JWT;
import com.auth0.jwt.algorithms.Algorithm;
import com.google.api.services.androidpublisher.model.SubscriptionPurchaseLineItem;
import com.google.api.services.androidpublisher.model.SubscriptionPurchaseV2;
import com.lifey.billing.AppleProperties;
import com.lifey.billing.GoogleProperties;
import com.lifey.billing.dto.EntitlementResponse;
import com.lifey.billing.dto.EntitlementSource;
import com.lifey.billing.dto.EntitlementTier;
import com.lifey.billing.dto.StorePurchasePlatform;
import com.lifey.billing.dto.StorePurchaseRequest;
import com.lifey.billing.entity.Subscription;
import com.lifey.billing.entity.SubscriptionProvider;
import com.lifey.billing.entity.SubscriptionStatus;
import com.lifey.billing.exception.InvalidReceiptException;
import com.lifey.billing.exception.SubscriptionAlreadyLinkedException;
import com.lifey.billing.repository.SubscriptionRepository;
import com.lifey.user.User;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.security.interfaces.ECPrivateKey;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * The Prompt 8 *Verify* line in docs/landing_page/64-billing-backend-plan.md:
 * "fixture-based test with a signed sandbox transaction; a tampered JWS →
 * 422; the same originalTransactionId for a second user → 409." Real StoreKit
 * 2 JWS cryptography throughout — {@link AppleTestChain} builds a genuine,
 * self-signed 3-certificate chain shaped like Apple's own, verified by the
 * real {@code SignedDataVerifier}/{@code ChainVerifier} from the App Store
 * Server library, not a stub.
 *
 * <p>Prompt 9's Android cases follow the same shape "as above" (its own
 * *Verify* line), plus an explicit assertion that {@code acknowledge} is
 * called — {@link PlayPurchaseClient} is mocked directly rather than given a
 * cryptographic fixture, since Play verification has no local check: the
 * {@code purchases.subscriptionsv2.get} call itself *is* the verification.
 */
@ExtendWith(MockitoExtension.class)
class StoreBillingServiceImplTest {

    private static final String BUNDLE_ID = "com.lifey.app";
    private static final String PACKAGE_NAME = "com.lifey.app";
    private static final Long USER_ID = 1L;
    private static final Instant NOW = Instant.parse("2026-06-15T09:00:00Z");

    /** Apple credentials are deliberately blank — the App Store Server API confirmation step must no-op, not call the network. */
    private static final AppleProperties APPLE_PROPERTIES =
            new AppleProperties(BUNDLE_ID, 1234L, Environment.SANDBOX, "", "", "");

    private static final GoogleProperties GOOGLE_PROPERTIES = new GoogleProperties(PACKAGE_NAME, "", "", "");

    private static AppleTestChain.Chain chain;

    @Mock
    PlayPurchaseClient playPurchaseClient;

    @Mock
    SubscriptionRepository subscriptionRepository;

    @Mock
    SubscriptionWriter subscriptionWriter;

    @Mock
    EntitlementService entitlementService;

    @BeforeAll
    static void generateChain() throws Exception {
        chain = AppleTestChain.generate();
    }

    private StoreBillingServiceImpl service() {
        SignedDataVerifier verifier = new SignedDataVerifier(
                Set.of(new ByteArrayInputStream(uncheckedEncode(chain.rootCertificate()))),
                BUNDLE_ID, 1234L, Environment.SANDBOX, false);
        return new StoreBillingServiceImpl(verifier, APPLE_PROPERTIES, playPurchaseClient, GOOGLE_PROPERTIES,
                subscriptionRepository, subscriptionWriter, entitlementService, Clock.fixed(NOW, ZoneOffset.UTC));
    }

    private static byte[] uncheckedEncode(java.security.cert.X509Certificate cert) {
        try {
            return cert.getEncoded();
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    private String signedTransaction(String originalTransactionId, String transactionId, String productId,
                                      long expiresDate, Long revocationDate) {
        String payload = """
                {
                  "originalTransactionId": "%s",
                  "transactionId": "%s",
                  "productId": "%s",
                  "bundleId": "%s",
                  "environment": "Sandbox",
                  "expiresDate": %d,
                  "signedDate": %d%s
                }
                """.formatted(originalTransactionId, transactionId, productId, BUNDLE_ID, expiresDate, NOW.toEpochMilli(),
                revocationDate == null ? "" : (",\n  \"revocationDate\": " + revocationDate));

        return JWT.create()
                .withHeader(Map.of("x5c", chain.x5c()))
                .withPayload(payload)
                .sign(Algorithm.ECDSA256((ECPrivateKey) chain.leafPrivateKey()));
    }

    private void stubNoExistingLink() {
        when(subscriptionRepository.findByProviderAndProviderSubscriptionId(any(), any())).thenReturn(Optional.empty());
    }

    private EntitlementResponse fakeEntitlement() {
        return new EntitlementResponse(EntitlementTier.PRO, EntitlementSource.APP_STORE, false, null, null,
                null, null, NOW, NOW, false);
    }

    // --- Happy path -----------------------------------------------------------------

    @Test
    void validSandboxTransaction_linksTheSubscription_andReturnsTheFreshEntitlement() {
        stubNoExistingLink();
        when(entitlementService.resolve(USER_ID)).thenReturn(fakeEntitlement());
        String jws = signedTransaction("2000000123456789", "2000000123456790", "pro.monthly",
                NOW.plusSeconds(86400).toEpochMilli(), null);

        EntitlementResponse response = service().verifyPurchase(USER_ID,
                new StorePurchaseRequest(StorePurchasePlatform.IOS, "pro.monthly", jws));

        assertThat(response.tier()).isEqualTo(EntitlementTier.PRO);
        ArgumentCaptor<SubscriptionStatus> statusCaptor = ArgumentCaptor.forClass(SubscriptionStatus.class);
        verify(subscriptionWriter).linkStorePurchase(eq(USER_ID), eq(SubscriptionProvider.APP_STORE),
                eq("2000000123456789"), statusCaptor.capture(), any());
        assertThat(statusCaptor.getValue()).isEqualTo(SubscriptionStatus.ACTIVE);
    }

    @Test
    void anAlreadyExpiredTransaction_linksAsExpired() {
        stubNoExistingLink();
        when(entitlementService.resolve(USER_ID)).thenReturn(fakeEntitlement());
        String jws = signedTransaction("2000000123456789", "2000000123456790", "pro.monthly",
                NOW.minusSeconds(3600).toEpochMilli(), null);

        service().verifyPurchase(USER_ID, new StorePurchaseRequest(StorePurchasePlatform.IOS, "pro.monthly", jws));

        ArgumentCaptor<SubscriptionStatus> statusCaptor = ArgumentCaptor.forClass(SubscriptionStatus.class);
        verify(subscriptionWriter).linkStorePurchase(eq(USER_ID), eq(SubscriptionProvider.APP_STORE),
                eq("2000000123456789"), statusCaptor.capture(), any());
        assertThat(statusCaptor.getValue()).isEqualTo(SubscriptionStatus.EXPIRED);
    }

    @Test
    void aRevokedTransaction_linksAsRefunded() {
        stubNoExistingLink();
        when(entitlementService.resolve(USER_ID)).thenReturn(fakeEntitlement());
        String jws = signedTransaction("2000000123456789", "2000000123456790", "pro.monthly",
                NOW.plusSeconds(86400).toEpochMilli(), NOW.minusSeconds(60).toEpochMilli());

        service().verifyPurchase(USER_ID, new StorePurchaseRequest(StorePurchasePlatform.IOS, "pro.monthly", jws));

        ArgumentCaptor<SubscriptionStatus> statusCaptor = ArgumentCaptor.forClass(SubscriptionStatus.class);
        verify(subscriptionWriter).linkStorePurchase(eq(USER_ID), eq(SubscriptionProvider.APP_STORE),
                eq("2000000123456789"), statusCaptor.capture(), any());
        assertThat(statusCaptor.getValue()).isEqualTo(SubscriptionStatus.REFUNDED);
    }

    // --- Tampered JWS -> 422 (InvalidReceiptException) --------------------------------

    @Test
    void tamperedSignature_isRejectedAsInvalidReceipt() {
        String jws = signedTransaction("2000000123456789", "2000000123456790", "pro.monthly",
                NOW.plusSeconds(86400).toEpochMilli(), null);
        String tampered = tamperSignature(jws);

        assertThatThrownBy(() -> service().verifyPurchase(USER_ID,
                new StorePurchaseRequest(StorePurchasePlatform.IOS, "pro.monthly", tampered)))
                .isInstanceOf(InvalidReceiptException.class);
    }

    @Test
    void malformedToken_isRejectedAsInvalidReceipt() {
        assertThatThrownBy(() -> service().verifyPurchase(USER_ID,
                new StorePurchaseRequest(StorePurchasePlatform.IOS, "pro.monthly", "not-a-real-jws")))
                .isInstanceOf(InvalidReceiptException.class);
    }

    @Test
    void wrongBundleId_isRejectedAsInvalidReceipt() {
        String payload = """
                {"originalTransactionId":"2000000123456789","transactionId":"2000000123456790",
                 "productId":"pro.monthly","bundleId":"com.someone.else","environment":"Sandbox",
                 "expiresDate":%d,"signedDate":%d}
                """.formatted(NOW.plusSeconds(86400).toEpochMilli(), NOW.toEpochMilli());
        String jws = JWT.create().withHeader(Map.of("x5c", chain.x5c())).withPayload(payload)
                .sign(Algorithm.ECDSA256((ECPrivateKey) chain.leafPrivateKey()));

        assertThatThrownBy(() -> service().verifyPurchase(USER_ID,
                new StorePurchaseRequest(StorePurchasePlatform.IOS, "pro.monthly", jws)))
                .isInstanceOf(InvalidReceiptException.class);
    }

    private static String tamperSignature(String jws) {
        int lastDot = jws.lastIndexOf('.');
        String signature = jws.substring(lastDot + 1);
        char flipped = signature.charAt(0) == 'A' ? 'B' : 'A';
        return jws.substring(0, lastDot + 1) + flipped + signature.substring(1);
    }

    // --- Same originalTransactionId, second user -> 409 (SubscriptionAlreadyLinkedException) ---

    @Test
    void sameOriginalTransactionId_forADifferentUser_isRejectedAsAlreadyLinked() {
        Long otherUserId = 2L;
        Subscription linkedToOtherUser = new Subscription();
        User otherUser = new User();
        otherUser.setId(otherUserId);
        linkedToOtherUser.setUser(otherUser);
        when(subscriptionRepository.findByProviderAndProviderSubscriptionId(SubscriptionProvider.APP_STORE, "2000000123456789"))
                .thenReturn(Optional.of(linkedToOtherUser));
        String jws = signedTransaction("2000000123456789", "2000000123456790", "pro.monthly",
                NOW.plusSeconds(86400).toEpochMilli(), null);

        assertThatThrownBy(() -> service().verifyPurchase(USER_ID,
                new StorePurchaseRequest(StorePurchasePlatform.IOS, "pro.monthly", jws)))
                .isInstanceOf(SubscriptionAlreadyLinkedException.class);
    }

    @Test
    void sameOriginalTransactionId_forTheSameUser_isAllowed_asAnIdempotentRefresh() {
        Subscription linkedToSameUser = new Subscription();
        User sameUser = new User();
        sameUser.setId(USER_ID);
        linkedToSameUser.setUser(sameUser);
        when(subscriptionRepository.findByProviderAndProviderSubscriptionId(SubscriptionProvider.APP_STORE, "2000000123456789"))
                .thenReturn(Optional.of(linkedToSameUser));
        when(entitlementService.resolve(USER_ID)).thenReturn(fakeEntitlement());
        String jws = signedTransaction("2000000123456789", "2000000123456790", "pro.monthly",
                NOW.plusSeconds(86400).toEpochMilli(), null);

        EntitlementResponse response = service().verifyPurchase(USER_ID,
                new StorePurchaseRequest(StorePurchasePlatform.IOS, "pro.monthly", jws));

        assertThat(response.tier()).isEqualTo(EntitlementTier.PRO);
    }

    // ============================================================================
    // Android (64 Prompt 9) — "as above" plus an explicit acknowledge assertion.
    // ============================================================================

    private static final String PURCHASE_TOKEN = "play-purchase-token-abc";

    private SubscriptionPurchaseV2 playSubscription(String state, String acknowledgementState, Long expiryEpochMilli) {
        SubscriptionPurchaseV2 purchase = new SubscriptionPurchaseV2();
        purchase.setSubscriptionState(state);
        purchase.setAcknowledgementState(acknowledgementState);
        if (expiryEpochMilli != null) {
            SubscriptionPurchaseLineItem lineItem = new SubscriptionPurchaseLineItem();
            lineItem.setProductId("pro.monthly");
            lineItem.setExpiryTime(Instant.ofEpochMilli(expiryEpochMilli).toString());
            purchase.setLineItems(List.of(lineItem));
        }
        return purchase;
    }

    private void stubNoExistingPlayLink() {
        when(subscriptionRepository.findByProviderAndProviderSubscriptionId(SubscriptionProvider.PLAY_STORE, PURCHASE_TOKEN))
                .thenReturn(Optional.empty());
    }

    @Test
    void validPlayPurchase_acknowledgesAndLinksTheSubscription() throws Exception {
        stubNoExistingPlayLink();
        when(entitlementService.resolve(USER_ID)).thenReturn(fakeEntitlement());
        SubscriptionPurchaseV2 purchase = playSubscription("SUBSCRIPTION_STATE_ACTIVE",
                "ACKNOWLEDGEMENT_STATE_PENDING", NOW.plusSeconds(86400).toEpochMilli());
        when(playPurchaseClient.getSubscription(PACKAGE_NAME, PURCHASE_TOKEN)).thenReturn(purchase);

        EntitlementResponse response = service().verifyPurchase(USER_ID,
                new StorePurchaseRequest(StorePurchasePlatform.ANDROID, "pro.monthly", PURCHASE_TOKEN));

        assertThat(response.tier()).isEqualTo(EntitlementTier.PRO);
        // The explicit "acknowledge is called" assertion the Prompt 9 *Verify* line asks for.
        verify(playPurchaseClient).acknowledge(PACKAGE_NAME, "pro.monthly", PURCHASE_TOKEN);
        ArgumentCaptor<SubscriptionStatus> statusCaptor = ArgumentCaptor.forClass(SubscriptionStatus.class);
        verify(subscriptionWriter).linkStorePurchase(eq(USER_ID), eq(SubscriptionProvider.PLAY_STORE),
                eq(PURCHASE_TOKEN), statusCaptor.capture(), any());
        assertThat(statusCaptor.getValue()).isEqualTo(SubscriptionStatus.ACTIVE);
    }

    @Test
    void alreadyAcknowledgedPlayPurchase_doesNotAcknowledgeAgain() throws Exception {
        stubNoExistingPlayLink();
        when(entitlementService.resolve(USER_ID)).thenReturn(fakeEntitlement());
        SubscriptionPurchaseV2 purchase = playSubscription("SUBSCRIPTION_STATE_ACTIVE",
                "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED", NOW.plusSeconds(86400).toEpochMilli());
        when(playPurchaseClient.getSubscription(PACKAGE_NAME, PURCHASE_TOKEN)).thenReturn(purchase);

        service().verifyPurchase(USER_ID, new StorePurchaseRequest(StorePurchasePlatform.ANDROID, "pro.monthly", PURCHASE_TOKEN));

        verify(playPurchaseClient, never()).acknowledge(any(), any(), any());
    }

    @Test
    void failedAcknowledge_isNotSwallowed_unlikeApplesConfirmationStep() throws Exception {
        stubNoExistingPlayLink();
        SubscriptionPurchaseV2 purchase = playSubscription("SUBSCRIPTION_STATE_ACTIVE",
                "ACKNOWLEDGEMENT_STATE_PENDING", NOW.plusSeconds(86400).toEpochMilli());
        when(playPurchaseClient.getSubscription(PACKAGE_NAME, PURCHASE_TOKEN)).thenReturn(purchase);
        doThrow(new IOException("Play API down"))
                .when(playPurchaseClient).acknowledge(any(), any(), any());

        assertThatThrownBy(() -> service().verifyPurchase(USER_ID,
                new StorePurchaseRequest(StorePurchasePlatform.ANDROID, "pro.monthly", PURCHASE_TOKEN)))
                .isInstanceOf(InvalidReceiptException.class);
        verify(subscriptionWriter, never()).linkStorePurchase(any(), any(), any(), any(), any());
    }

    @Test
    void playApiFailure_isRejectedAsInvalidReceipt() throws Exception {
        when(playPurchaseClient.getSubscription(PACKAGE_NAME, PURCHASE_TOKEN))
                .thenThrow(new IOException("not found"));

        assertThatThrownBy(() -> service().verifyPurchase(USER_ID,
                new StorePurchaseRequest(StorePurchasePlatform.ANDROID, "pro.monthly", PURCHASE_TOKEN)))
                .isInstanceOf(InvalidReceiptException.class);
    }

    @Test
    void onHoldPlayState_mapsToPastDue() throws Exception {
        stubNoExistingPlayLink();
        when(entitlementService.resolve(USER_ID)).thenReturn(fakeEntitlement());
        SubscriptionPurchaseV2 purchase = playSubscription("SUBSCRIPTION_STATE_ON_HOLD",
                "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED", NOW.plusSeconds(86400).toEpochMilli());
        when(playPurchaseClient.getSubscription(PACKAGE_NAME, PURCHASE_TOKEN)).thenReturn(purchase);

        service().verifyPurchase(USER_ID, new StorePurchaseRequest(StorePurchasePlatform.ANDROID, "pro.monthly", PURCHASE_TOKEN));

        ArgumentCaptor<SubscriptionStatus> statusCaptor = ArgumentCaptor.forClass(SubscriptionStatus.class);
        verify(subscriptionWriter).linkStorePurchase(eq(USER_ID), eq(SubscriptionProvider.PLAY_STORE),
                eq(PURCHASE_TOKEN), statusCaptor.capture(), any());
        assertThat(statusCaptor.getValue()).isEqualTo(SubscriptionStatus.PAST_DUE);
    }

    @Test
    void samePlayPurchaseToken_forADifferentUser_isRejectedAsAlreadyLinked() {
        Long otherUserId = 2L;
        Subscription linkedToOtherUser = new Subscription();
        User otherUser = new User();
        otherUser.setId(otherUserId);
        linkedToOtherUser.setUser(otherUser);
        when(subscriptionRepository.findByProviderAndProviderSubscriptionId(SubscriptionProvider.PLAY_STORE, PURCHASE_TOKEN))
                .thenReturn(Optional.of(linkedToOtherUser));

        assertThatThrownBy(() -> service().verifyPurchase(USER_ID,
                new StorePurchaseRequest(StorePurchasePlatform.ANDROID, "pro.monthly", PURCHASE_TOKEN)))
                .isInstanceOf(SubscriptionAlreadyLinkedException.class);
    }
}

package com.lifey.billing.service;

import com.google.api.client.googleapis.javanet.GoogleNetHttpTransport;
import com.google.api.client.json.gson.GsonFactory;
import com.google.api.services.androidpublisher.AndroidPublisher;
import com.google.api.services.androidpublisher.AndroidPublisherScopes;
import com.google.api.services.androidpublisher.model.SubscriptionPurchaseV2;
import com.google.api.services.androidpublisher.model.SubscriptionPurchasesAcknowledgeRequest;
import com.google.auth.http.HttpCredentialsAdapter;
import com.google.auth.oauth2.GoogleCredentials;
import com.lifey.billing.GoogleProperties;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;

/**
 * Builds a real {@code AndroidPublisher} fresh on every call rather than as a
 * field — {@code GoogleCredentials.fromStream} parses the service-account key
 * eagerly, so holding one instance would either fail application startup with
 * no key configured or go stale if the key is rotated (64 §6.1).
 */
@Component
@RequiredArgsConstructor
class PlayPurchaseClientImpl implements PlayPurchaseClient {

    private static final String APPLICATION_NAME = "Lifey";

    private final GoogleProperties googleProperties;

    @Override
    public SubscriptionPurchaseV2 getSubscription(String packageName, String purchaseToken) throws IOException {
        return androidPublisher().purchases().subscriptionsv2().get(packageName, purchaseToken).execute();
    }

    @Override
    public void acknowledge(String packageName, String productId, String purchaseToken) throws IOException {
        androidPublisher().purchases().subscriptions()
                .acknowledge(packageName, productId, purchaseToken, new SubscriptionPurchasesAcknowledgeRequest())
                .execute();
    }

    private AndroidPublisher androidPublisher() throws IOException {
        GoogleCredentials credentials = GoogleCredentials.fromStream(
                        new ByteArrayInputStream(googleProperties.serviceAccountJson().getBytes(StandardCharsets.UTF_8)))
                .createScoped(AndroidPublisherScopes.ANDROIDPUBLISHER);
        try {
            return new AndroidPublisher.Builder(GoogleNetHttpTransport.newTrustedTransport(), GsonFactory.getDefaultInstance(),
                    new HttpCredentialsAdapter(credentials))
                    .setApplicationName(APPLICATION_NAME)
                    .build();
        } catch (GeneralSecurityException e) {
            throw new IOException("Could not build a trusted HTTP transport for the Play Developer API", e);
        }
    }
}

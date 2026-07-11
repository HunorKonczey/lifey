package com.lifey.push.service;

import com.eatthepath.pushy.apns.ApnsClient;
import com.eatthepath.pushy.apns.ApnsClientBuilder;
import com.eatthepath.pushy.apns.PushNotificationResponse;
import com.eatthepath.pushy.apns.auth.ApnsSigningKey;
import com.eatthepath.pushy.apns.util.ApnsPayloadBuilder;
import com.eatthepath.pushy.apns.util.SimpleApnsPayloadBuilder;
import com.eatthepath.pushy.apns.util.SimpleApnsPushNotification;
import com.lifey.push.PushDevice;
import com.lifey.push.PushPlatform;
import com.lifey.push.PushProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import java.io.File;
import java.io.IOException;
import java.security.GeneralSecurityException;
import java.time.Duration;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

/**
 * APNs sender (docs/30-push-notifications-plan.md, B2), token-based auth via
 * a {@code .p8} key — no cert renewal. Only created when
 * {@code lifey.push.apns.enabled=true}, so local dev/CI never need real APNs
 * credentials (see {@link PushProperties}); {@link PushServiceImpl} simply
 * has no sender for {@link PushPlatform#IOS} in that case and skips iOS
 * devices.
 */
@Component
@ConditionalOnProperty(prefix = "lifey.push.apns", name = "enabled", havingValue = "true")
class ApnsPushSender implements PushSender {

    private static final Logger log = LoggerFactory.getLogger(ApnsPushSender.class);
    private static final Duration SEND_TIMEOUT = Duration.ofSeconds(10);

    private final ApnsClient client;
    private final String topic;

    ApnsPushSender(PushProperties properties) {
        try {
            ApnsSigningKey signingKey = ApnsSigningKey.loadFromPkcs8File(
                    new File(properties.keyPath()), properties.teamId(), properties.keyId());
            this.client = new ApnsClientBuilder()
                    .setApnsServer(properties.sandbox()
                            ? ApnsClientBuilder.DEVELOPMENT_APNS_HOST
                            : ApnsClientBuilder.PRODUCTION_APNS_HOST)
                    .setSigningKey(signingKey)
                    .build();
            this.topic = properties.bundleId();
        } catch (GeneralSecurityException | IOException e) {
            throw new IllegalStateException("Failed to initialize APNs client from " + properties.keyPath(), e);
        }
    }

    @Override
    public boolean supports(PushPlatform platform) {
        return platform == PushPlatform.IOS;
    }

    @Override
    public PushSendResult send(PushDevice device, PushMessage message) {
        ApnsPayloadBuilder payloadBuilder = new SimpleApnsPayloadBuilder()
                .setAlertTitle(message.title())
                .setAlertBody(message.body());
        // Deep-link payload (e.g. type=scheduled_workout) — delivered as
        // top-level custom keys alongside "aps", read by the app as
        // UNNotification.request.content.userInfo (see docs/30-push-notifications-plan.md, M3).
        message.data().forEach(payloadBuilder::addCustomProperty);
        String payload = payloadBuilder.build();
        SimpleApnsPushNotification notification =
                new SimpleApnsPushNotification(device.getToken(), topic, payload);

        try {
            PushNotificationResponse<SimpleApnsPushNotification> response =
                    client.sendNotification(notification).get(SEND_TIMEOUT.toSeconds(), TimeUnit.SECONDS);
            if (response.isAccepted()) {
                return PushSendResult.DELIVERED;
            }
            String reason = response.getRejectionReason().orElse("unknown");
            if (isTokenInvalidReason(reason)) {
                return PushSendResult.TOKEN_INVALID;
            }
            log.warn("APNs rejected notification to device {}: {}", device.getId(), reason);
            return PushSendResult.FAILED;
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return PushSendResult.FAILED;
        } catch (ExecutionException | TimeoutException e) {
            log.error("Failed to send APNs notification to device {}", device.getId(), e);
            return PushSendResult.FAILED;
        }
    }

    private static boolean isTokenInvalidReason(String reason) {
        return "BadDeviceToken".equals(reason) || "Unregistered".equals(reason) || "ExpiredToken".equals(reason);
    }
}

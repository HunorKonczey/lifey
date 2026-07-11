package com.lifey.push.service;

import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.MessagingErrorCode;
import com.google.firebase.messaging.Notification;
import com.lifey.push.PushDevice;
import com.lifey.push.PushPlatform;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * Android sender via Firebase Cloud Messaging (docs/30-push-notifications-plan.md,
 * B2 Android follow-up). Only created when {@code lifey.push.fcm.enabled=true}
 * (see {@code FcmConfig}); {@link PushServiceImpl} simply has no sender for
 * {@link PushPlatform#ANDROID} otherwise and skips Android devices.
 */
@Component
@ConditionalOnProperty(prefix = "lifey.push.fcm", name = "enabled", havingValue = "true")
class FcmPushSender implements PushSender {

    private static final Logger log = LoggerFactory.getLogger(FcmPushSender.class);

    private final FirebaseMessaging firebaseMessaging;

    FcmPushSender(FirebaseMessaging firebaseMessaging) {
        this.firebaseMessaging = firebaseMessaging;
    }

    @Override
    public boolean supports(PushPlatform platform) {
        return platform == PushPlatform.ANDROID;
    }

    @Override
    public PushSendResult send(PushDevice device, PushMessage message) {
        Message fcmMessage = Message.builder()
                .setToken(device.getToken())
                .setNotification(Notification.builder()
                        .setTitle(message.title())
                        .setBody(message.body())
                        .build())
                .putAllData(message.data())
                .build();

        try {
            firebaseMessaging.send(fcmMessage);
            return PushSendResult.DELIVERED;
        } catch (FirebaseMessagingException e) {
            if (e.getMessagingErrorCode() == MessagingErrorCode.UNREGISTERED) {
                return PushSendResult.TOKEN_INVALID;
            }
            log.warn("FCM rejected notification to device {}: {}", device.getId(), e.getMessagingErrorCode());
            return PushSendResult.FAILED;
        }
    }
}

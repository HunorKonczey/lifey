package com.lifey.push;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Bound from {@code lifey.push.fcm.*} (see application.yml). {@code enabled}
 * gates whether the Firebase beans (and {@code FcmPushSender}) are created at
 * all — off by default so local dev and tests never need real Firebase
 * credentials. {@code credentialsPath} is a Firebase service-account JSON key
 * (Project settings > Service accounts > Generate new private key).
 */
@ConfigurationProperties(prefix = "lifey.push.fcm")
public record FcmProperties(
        boolean enabled,
        String credentialsPath
) {
}

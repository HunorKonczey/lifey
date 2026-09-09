package com.lifey.billing.controller.webhook;

import java.util.Arrays;
import java.util.Optional;

/**
 * Google's integer notification-type codes for a Play RTDN {@code
 * subscriptionNotification} (docs/landing_page/64-billing-backend-plan.md
 * §6.2) — Google ships no Java enum for these, only documents the raw ints.
 */
enum PlayNotificationType {
    SUBSCRIPTION_RECOVERED(1),
    SUBSCRIPTION_RENEWED(2),
    SUBSCRIPTION_CANCELED(3),
    SUBSCRIPTION_PURCHASED(4),
    SUBSCRIPTION_ON_HOLD(5),
    SUBSCRIPTION_IN_GRACE_PERIOD(6),
    SUBSCRIPTION_RESTARTED(7),
    SUBSCRIPTION_PRICE_CHANGE_CONFIRMED(8),
    SUBSCRIPTION_DEFERRED(9),
    SUBSCRIPTION_PAUSED(10),
    SUBSCRIPTION_PAUSE_SCHEDULE_CHANGED(11),
    SUBSCRIPTION_REVOKED(12),
    SUBSCRIPTION_EXPIRED(13);

    private final int code;

    PlayNotificationType(int code) {
        this.code = code;
    }

    static Optional<PlayNotificationType> fromCode(int code) {
        return Arrays.stream(values()).filter(type -> type.code == code).findFirst();
    }
}

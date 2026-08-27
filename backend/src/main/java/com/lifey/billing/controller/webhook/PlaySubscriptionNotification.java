package com.lifey.billing.controller.webhook;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

/** {@code notificationType} is Google's integer code (see {@link PlayNotificationType}); {@code purchaseToken} is the identity (D-B6). */
@JsonIgnoreProperties(ignoreUnknown = true)
record PlaySubscriptionNotification(int notificationType, String purchaseToken, String subscriptionId) {
}

package com.lifey.billing.controller.webhook;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

/**
 * The base64-decoded RTDN payload (Real-time developer notifications, 64
 * §6.2). Google ships no Java model for this shape (unlike the Play
 * Developer API's generated classes) — {@code subscriptionNotification} is
 * null for the other notification kinds (test/one-time-product), which are
 * simply unhandled here.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
record PlayDeveloperNotification(String packageName, String eventTimeMillis, PlaySubscriptionNotification subscriptionNotification) {
}

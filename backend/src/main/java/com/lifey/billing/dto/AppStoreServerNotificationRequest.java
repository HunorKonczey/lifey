package com.lifey.billing.dto;

/** The whole ASSN V2 HTTP body — one field, the outer signed envelope (64 §6.2). */
public record AppStoreServerNotificationRequest(String signedPayload) {
}

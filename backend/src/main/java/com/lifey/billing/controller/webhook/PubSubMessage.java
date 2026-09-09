package com.lifey.billing.controller.webhook;

/** {@code data} is the base64-encoded RTDN JSON payload; {@code messageId} is the idempotency key (64 §6.2). */
record PubSubMessage(String data, String messageId, String publishTime) {
}

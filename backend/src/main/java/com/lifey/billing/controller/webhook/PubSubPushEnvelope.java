package com.lifey.billing.controller.webhook;

/** The outer envelope every Pub/Sub push delivery arrives in — not Play-specific. */
record PubSubPushEnvelope(PubSubMessage message, String subscription) {
}

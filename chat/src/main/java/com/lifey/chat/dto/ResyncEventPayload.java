package com.lifey.chat.dto;

/**
 * Body of an {@code event: resync} frame. The stream is a fast path over REST,
 * never the source of truth (§4.4) — when it cannot bridge a gap it says so and
 * the client reloads.
 */
public record ResyncEventPayload(String reason) {
}

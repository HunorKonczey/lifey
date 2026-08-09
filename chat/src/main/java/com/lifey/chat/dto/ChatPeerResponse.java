package com.lifey.chat.dto;

/**
 * The other participant, as the caller sees them.
 *
 * <p>No {@code avatarUrl}, deliberately: profile pictures live in the
 * monolith's {@code user} feature, which this service cannot read at all (its
 * database role has no grant on {@code user_avatars}). Clients fetch the
 * picture themselves from {@code GET /api/v1/users/{userId}/avatar} — the
 * monolith authorizes it on the same trainer-client link the thread rests on —
 * and fall back to a monogram derived from {@code displayName}. See
 * docs/chat/40-trainer-chat-plan.md §11.
 */
public record ChatPeerResponse(
        Long userId,
        String displayName,
        String email,
        ChatPeerRole role
) {
}

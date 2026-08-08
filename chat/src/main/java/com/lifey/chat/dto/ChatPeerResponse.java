package com.lifey.chat.dto;

/**
 * The other participant, as the caller sees them.
 *
 * <p>No {@code avatarUrl} yet: profile pictures are only reachable for the
 * caller's own account ({@code /api/v1/users/me/avatar}), there is no
 * cross-user avatar route to point at. The chat design uses monogram avatars
 * derived from {@code displayName}, so nothing is blocked on it — see
 * docs/chat/40-trainer-chat-plan.md §11.
 */
public record ChatPeerResponse(
        Long userId,
        String displayName,
        String email,
        ChatPeerRole role
) {
}

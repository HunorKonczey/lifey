package com.lifey.auth;

/**
 * Published after a Google social login resolves a user, when the verified ID
 * token carried a {@code picture} claim. {@link GoogleAvatarImportListener}
 * downloads and stores it — but only if the user has no avatar yet, see there.
 */
public record GoogleAvatarCandidateEvent(Long userId, String pictureUrl) {
}

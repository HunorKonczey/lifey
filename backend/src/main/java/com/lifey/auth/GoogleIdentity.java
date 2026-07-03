package com.lifey.auth;

/**
 * Claims extracted from a verified Google ID token. {@code picture} is present
 * whenever the token was requested with the default {@code profile} scope
 * (the mobile/web clients always do) — null otherwise, never an error either
 * way. See {@link GoogleAvatarImportListener} for what it's used for.
 */
public record GoogleIdentity(String sub, String email, boolean emailVerified, String picture) {
}

package com.lifey.auth;

/**
 * Claims extracted from a verified Google ID token. {@code picture} is present
 * whenever the token was requested with the default {@code profile} scope
 * (the mobile/web clients always do) — null otherwise, never an error either
 * way. See {@link GoogleAvatarImportListener} for what it's used for.
 * {@code givenName}/{@code familyName} come from the "given_name"/"family_name"
 * claims — Google already splits a middle name into {@code givenName} by
 * convention, so no further splitting is needed on our side.
 */
public record GoogleIdentity(
        String sub, String email, boolean emailVerified, String picture,
        String givenName, String familyName) {
}

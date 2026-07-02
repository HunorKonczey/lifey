package com.lifey.auth;

/**
 * Claims extracted from a verified Google ID token.
 */
public record GoogleIdentity(String sub, String email, boolean emailVerified) {
}

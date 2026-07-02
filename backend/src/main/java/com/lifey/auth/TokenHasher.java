package com.lifey.auth;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.HexFormat;

/**
 * Generates opaque refresh token values and hashes them for storage.
 * Refresh tokens are random bytes, not JWTs — only {@link #hash} ever touches
 * the database, so a DB leak alone can't be replayed as a working session.
 */
public final class TokenHasher {

    private static final SecureRandom RANDOM = new SecureRandom();

    private TokenHasher() {
    }

    public static String generateOpaqueToken() {
        byte[] bytes = new byte[32];
        RANDOM.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    public static String hash(String rawToken) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hashed = digest.digest(rawToken.getBytes(java.nio.charset.StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(hashed);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 not available", e);
        }
    }
}

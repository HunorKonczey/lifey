package com.lifey.auth;

import com.lifey.auth.exception.InvalidSocialTokenException;

import com.lifey.auth.properties.GoogleOAuthProperties;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtException;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Set;

/**
 * Verifies Google-issued ID tokens against Google's published JWKS.
 * {@link NimbusJwtDecoder} checks the signature and timestamps (and caches the
 * JWKS internally); issuer and audience are checked here since Spring's
 * default JWT validator only checks timestamps.
 */
@Service
public class GoogleIdTokenVerifier {

    private static final String JWKS_URI = "https://www.googleapis.com/oauth2/v3/certs";
    private static final Set<String> VALID_ISSUERS = Set.of("https://accounts.google.com", "accounts.google.com");

    private final JwtDecoder jwtDecoder;
    private final GoogleOAuthProperties properties;

    @Autowired
    GoogleIdTokenVerifier(GoogleOAuthProperties properties) {
        this(properties, NimbusJwtDecoder.withJwkSetUri(JWKS_URI).build());
    }

    /**
     * Visible for tests, to inject a decoder backed by a local JWK set instead of Google's live JWKS.
     */
    GoogleIdTokenVerifier(GoogleOAuthProperties properties, JwtDecoder jwtDecoder) {
        this.properties = properties;
        this.jwtDecoder = jwtDecoder;
    }

    public GoogleIdentity verify(String idToken) {
        Jwt jwt;
        try {
            jwt = jwtDecoder.decode(idToken);
        } catch (JwtException ex) {
            throw new InvalidSocialTokenException("Invalid Google ID token");
        }

        if (!VALID_ISSUERS.contains(jwt.getClaimAsString("iss"))) {
            throw new InvalidSocialTokenException("Invalid Google ID token issuer");
        }

        List<String> audience = jwt.getAudience();
        if (audience == null || audience.stream().noneMatch(properties.clientIds()::contains)) {
            throw new InvalidSocialTokenException("Invalid Google ID token audience");
        }

        String sub = jwt.getSubject();
        String email = jwt.getClaimAsString("email");
        if (sub == null || email == null) {
            throw new InvalidSocialTokenException("Google ID token missing required claims");
        }

        boolean emailVerified = Boolean.TRUE.equals(jwt.getClaimAsBoolean("email_verified"));
        return new GoogleIdentity(sub, email, emailVerified);
    }
}

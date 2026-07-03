package com.lifey.auth;

import com.lifey.auth.exception.InvalidSocialTokenException;

import com.lifey.auth.properties.GoogleOAuthProperties;
import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.JWSHeader;
import com.nimbusds.jose.crypto.RSASSASigner;
import com.nimbusds.jose.jwk.JWKSet;
import com.nimbusds.jose.jwk.RSAKey;
import com.nimbusds.jose.jwk.source.ImmutableJWKSet;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;

import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.interfaces.RSAPrivateKey;
import java.security.interfaces.RSAPublicKey;
import java.time.Instant;
import java.util.Date;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Verifies {@link GoogleIdTokenVerifier} against locally-signed tokens and an
 * in-memory JWK set, standing in for Google's real JWKS endpoint.
 */
class GoogleIdTokenVerifierTest {

    private static final String CLIENT_ID = "test-client-id.apps.googleusercontent.com";
    private static final String SUBJECT = "google-user-123";

    private RSAPrivateKey privateKey;
    private String keyId;
    private GoogleIdTokenVerifier verifier;

    @BeforeEach
    void setUp() throws Exception {
        KeyPairGenerator generator = KeyPairGenerator.getInstance("RSA");
        generator.initialize(2048);
        KeyPair keyPair = generator.generateKeyPair();
        privateKey = (RSAPrivateKey) keyPair.getPrivate();
        keyId = UUID.randomUUID().toString();

        RSAKey jwk = new RSAKey.Builder((RSAPublicKey) keyPair.getPublic())
                .keyID(keyId)
                .build();
        JwtDecoder jwtDecoder = NimbusJwtDecoder.withJwkSource(new ImmutableJWKSet<>(new JWKSet(jwk))).build();

        verifier = new GoogleIdTokenVerifier(new GoogleOAuthProperties(List.of(CLIENT_ID)), jwtDecoder);
    }

    @Test
    void verify_validToken_returnsIdentity() throws Exception {
        String token = signedToken("https://accounts.google.com", CLIENT_ID, "user@example.com", true,
                Instant.now().plusSeconds(300));

        GoogleIdentity identity = verifier.verify(token);

        assertThat(identity.sub()).isEqualTo(SUBJECT);
        assertThat(identity.email()).isEqualTo("user@example.com");
        assertThat(identity.emailVerified()).isTrue();
        assertThat(identity.picture()).isNull();
    }

    @Test
    void verify_tokenWithPictureClaim_returnsIdentityWithPicture() throws Exception {
        JWTClaimsSet.Builder claims = new JWTClaimsSet.Builder()
                .subject(SUBJECT)
                .issuer("https://accounts.google.com")
                .audience(CLIENT_ID)
                .expirationTime(Date.from(Instant.now().plusSeconds(300)))
                .claim("email", "user@example.com")
                .claim("email_verified", true)
                .claim("picture", "https://lh3.googleusercontent.com/a/abc123=s96-c");
        SignedJWT jwt = new SignedJWT(new JWSHeader.Builder(JWSAlgorithm.RS256).keyID(keyId).build(), claims.build());
        jwt.sign(new RSASSASigner(privateKey));

        GoogleIdentity identity = verifier.verify(jwt.serialize());

        assertThat(identity.picture()).isEqualTo("https://lh3.googleusercontent.com/a/abc123=s96-c");
    }

    @Test
    void verify_unverifiedEmailClaim_returnsIdentityWithFlagFalse() throws Exception {
        String token = signedToken("https://accounts.google.com", CLIENT_ID, "user@example.com", false,
                Instant.now().plusSeconds(300));

        assertThat(verifier.verify(token).emailVerified()).isFalse();
    }

    @Test
    void verify_wrongIssuer_throws() throws Exception {
        String token = signedToken("https://evil.example.com", CLIENT_ID, "user@example.com", true,
                Instant.now().plusSeconds(300));

        assertThatThrownBy(() -> verifier.verify(token)).isInstanceOf(InvalidSocialTokenException.class);
    }

    @Test
    void verify_wrongAudience_throws() throws Exception {
        String token = signedToken("https://accounts.google.com", "someone-elses-client-id", "user@example.com", true,
                Instant.now().plusSeconds(300));

        assertThatThrownBy(() -> verifier.verify(token)).isInstanceOf(InvalidSocialTokenException.class);
    }

    @Test
    void verify_expiredToken_throws() throws Exception {
        String token = signedToken("https://accounts.google.com", CLIENT_ID, "user@example.com", true,
                Instant.now().minusSeconds(300));

        assertThatThrownBy(() -> verifier.verify(token)).isInstanceOf(InvalidSocialTokenException.class);
    }

    @Test
    void verify_missingEmailClaim_throws() throws Exception {
        String token = signedToken("https://accounts.google.com", CLIENT_ID, null, null,
                Instant.now().plusSeconds(300));

        assertThatThrownBy(() -> verifier.verify(token)).isInstanceOf(InvalidSocialTokenException.class);
    }

    @Test
    void verify_malformedToken_throws() {
        assertThatThrownBy(() -> verifier.verify("not-a-jwt")).isInstanceOf(InvalidSocialTokenException.class);
    }

    private String signedToken(String issuer, String audience, String email, Boolean emailVerified, Instant expiry)
            throws Exception {
        JWTClaimsSet.Builder claims = new JWTClaimsSet.Builder()
                .subject(SUBJECT)
                .issuer(issuer)
                .audience(audience)
                .expirationTime(Date.from(expiry));
        if (email != null) {
            claims.claim("email", email);
        }
        if (emailVerified != null) {
            claims.claim("email_verified", emailVerified);
        }

        SignedJWT jwt = new SignedJWT(new JWSHeader.Builder(JWSAlgorithm.RS256).keyID(keyId).build(), claims.build());
        jwt.sign(new RSASSASigner(privateKey));
        return jwt.serialize();
    }
}

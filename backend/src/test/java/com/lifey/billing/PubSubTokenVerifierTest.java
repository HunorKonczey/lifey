package com.lifey.billing;

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
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Verifies {@link PubSubTokenVerifier} against locally-signed tokens and an
 * in-memory JWK set, standing in for Google's real JWKS endpoint — same
 * pattern as {@code com.lifey.auth.GoogleIdTokenVerifierTest} (`64` Prompt 10).
 */
class PubSubTokenVerifierTest {

    private static final String AUDIENCE = "https://api.lifey.app/api/v1/webhooks/play";
    private static final String SERVICE_ACCOUNT_EMAIL = "play-rtdn@lifey-prod.iam.gserviceaccount.com";
    private static final String SUBJECT = "pubsub-push-subscription";

    private RSAPrivateKey privateKey;
    private String keyId;
    private PubSubTokenVerifier verifier;

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

        GoogleProperties properties = new GoogleProperties("com.lifey.app", "", AUDIENCE, SERVICE_ACCOUNT_EMAIL);
        verifier = new PubSubTokenVerifier(properties, jwtDecoder);
    }

    @Test
    void isValid_correctIssuerAudienceAndVerifiedServiceAccountEmail_returnsTrue() throws Exception {
        String token = signedToken("https://accounts.google.com", AUDIENCE, SERVICE_ACCOUNT_EMAIL, true);

        assertThat(verifier.isValid(token)).isTrue();
    }

    @Test
    void isValid_bareIssuerVariant_returnsTrue() throws Exception {
        String token = signedToken("accounts.google.com", AUDIENCE, SERVICE_ACCOUNT_EMAIL, true);

        assertThat(verifier.isValid(token)).isTrue();
    }

    @Test
    void isValid_wrongIssuer_returnsFalse() throws Exception {
        String token = signedToken("https://evil.example.com", AUDIENCE, SERVICE_ACCOUNT_EMAIL, true);

        assertThat(verifier.isValid(token)).isFalse();
    }

    @Test
    void isValid_wrongAudience_returnsFalse() throws Exception {
        String token = signedToken("https://accounts.google.com", "https://someone-elses-endpoint.example.com",
                SERVICE_ACCOUNT_EMAIL, true);

        assertThat(verifier.isValid(token)).isFalse();
    }

    @Test
    void isValid_wrongServiceAccountEmail_returnsFalse() throws Exception {
        String token = signedToken("https://accounts.google.com", AUDIENCE, "someone-else@example.com", true);

        assertThat(verifier.isValid(token)).isFalse();
    }

    @Test
    void isValid_unverifiedEmail_returnsFalse() throws Exception {
        String token = signedToken("https://accounts.google.com", AUDIENCE, SERVICE_ACCOUNT_EMAIL, false);

        assertThat(verifier.isValid(token)).isFalse();
    }

    @Test
    void isValid_malformedToken_returnsFalse() {
        assertThat(verifier.isValid("not-a-jwt")).isFalse();
    }

    private String signedToken(String issuer, String audience, String email, boolean emailVerified) throws Exception {
        JWTClaimsSet.Builder claims = new JWTClaimsSet.Builder()
                .subject(SUBJECT)
                .issuer(issuer)
                .audience(audience)
                .expirationTime(Date.from(Instant.now().plusSeconds(300)))
                .claim("email", email)
                .claim("email_verified", emailVerified);
        SignedJWT jwt = new SignedJWT(new JWSHeader.Builder(JWSAlgorithm.RS256).keyID(keyId).build(), claims.build());
        jwt.sign(new RSASSASigner(privateKey));
        return jwt.serialize();
    }
}

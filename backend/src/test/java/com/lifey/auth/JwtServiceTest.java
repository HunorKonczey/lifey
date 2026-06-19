package com.lifey.auth;

import com.lifey.user.Role;
import com.lifey.user.User;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.junit.jupiter.api.Test;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.Date;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class JwtServiceTest {

    private final JwtProperties properties = new JwtProperties(
            "test-secret-key-at-least-256-bits-long-for-hmac-sha",
            Duration.ofMinutes(15),
            Duration.ofDays(30),
            "lifey-api");

    private final JwtService jwtService = new JwtService(properties);

    @Test
    void generateAccessToken_roundTripsClaims() {
        User user = user(7L, "user@example.com", Role.ROLE_USER, Role.ROLE_ADMIN);

        String token = jwtService.generateAccessToken(user);
        var claims = jwtService.parseAccessToken(token);

        assertThat(jwtService.extractUserId(claims)).isEqualTo(7L);
        assertThat(claims.get("email", String.class)).isEqualTo("user@example.com");
        assertThat(jwtService.extractRoles(claims)).containsExactlyInAnyOrder(Role.ROLE_USER, Role.ROLE_ADMIN);
        assertThat(claims.getIssuer()).isEqualTo("lifey-api");
    }

    @Test
    void extractRoles_returnsEmptySetWhenClaimMissing() {
        SecretKey key = Keys.hmacShaKeyFor(properties.secret().getBytes(StandardCharsets.UTF_8));
        String token = Jwts.builder()
                .subject("1")
                .issuedAt(Date.from(Instant.now()))
                .expiration(Date.from(Instant.now().plus(Duration.ofMinutes(5))))
                .signWith(key)
                .compact();

        var claims = jwtService.parseAccessToken(token);

        assertThat(jwtService.extractRoles(claims)).isEmpty();
    }

    @Test
    void parseAccessToken_expiredTokenThrowsTokenExpiredException() {
        SecretKey key = Keys.hmacShaKeyFor(properties.secret().getBytes(StandardCharsets.UTF_8));
        String expiredToken = Jwts.builder()
                .subject("1")
                .issuedAt(Date.from(Instant.now().minus(Duration.ofHours(1))))
                .expiration(Date.from(Instant.now().minus(Duration.ofMinutes(1))))
                .signWith(key)
                .compact();

        assertThatThrownBy(() -> jwtService.parseAccessToken(expiredToken))
                .isInstanceOf(TokenExpiredException.class);
    }

    @Test
    void parseAccessToken_malformedTokenThrowsInvalidTokenException() {
        assertThatThrownBy(() -> jwtService.parseAccessToken("not-a-jwt"))
                .isInstanceOf(InvalidTokenException.class);
    }

    @Test
    void parseAccessToken_wrongSignatureThrowsInvalidTokenException() {
        User user = user(1L, "user@example.com", Role.ROLE_USER);
        String token = jwtService.generateAccessToken(user);

        JwtProperties otherProperties = new JwtProperties(
                "a-completely-different-secret-key-also-256-bits-long",
                Duration.ofMinutes(15),
                Duration.ofDays(30),
                "lifey-api");
        JwtService otherJwtService = new JwtService(otherProperties);

        assertThatThrownBy(() -> otherJwtService.parseAccessToken(token))
                .isInstanceOf(InvalidTokenException.class);
    }

    @Test
    void accessTokenTtlSeconds_matchesConfiguredDuration() {
        assertThat(jwtService.accessTokenTtlSeconds()).isEqualTo(900L);
    }

    @Test
    void refreshTokenTtl_matchesConfiguredDuration() {
        assertThat(jwtService.refreshTokenTtl()).isEqualTo(Duration.ofDays(30));
    }

    private static User user(Long id, String email, Role... roles) {
        User user = new User();
        user.setId(id);
        user.setEmail(email);
        user.setRoles(Set.of(roles));
        return user;
    }
}

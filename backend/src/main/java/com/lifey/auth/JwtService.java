package com.lifey.auth;

import com.lifey.auth.entity.RefreshToken;
import com.lifey.auth.exception.InvalidTokenException;
import com.lifey.auth.exception.TokenExpiredException;

import com.lifey.auth.properties.JwtProperties;
import com.lifey.user.Role;
import com.lifey.user.User;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.Date;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * Issues and verifies the short-lived JWT access token. Refresh tokens are
 * deliberately NOT JWTs (see {@link RefreshToken}) — they're opaque, hashed,
 * database-backed values, so they can be revoked instantly and individually,
 * which a self-contained signed JWT cannot be without a separate denylist.
 */
@Service
public class JwtService {

    private final SecretKey key;
    private final JwtProperties properties;

    public JwtService(JwtProperties properties) {
        this.properties = properties;
        this.key = Keys.hmacShaKeyFor(properties.secret().getBytes(StandardCharsets.UTF_8));
    }

    public String generateAccessToken(User user) {
        Instant now = Instant.now();
        return Jwts.builder()
                .subject(user.getId().toString())
                .claim("email", user.getEmail())
                .claim("firstName", user.getFirstName())
                .claim("lastName", user.getLastName())
                .claim("roles", user.getRoles().stream().map(Enum::name).toList())
                .issuer(properties.issuer())
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plus(properties.accessTokenTtl())))
                .signWith(key)
                .compact();
    }

    /**
     * Verifies signature and expiry and returns the decoded claims.
     *
     * @throws TokenExpiredException if the token's signature is valid, but it has expired
     * @throws InvalidTokenException if the token is malformed or its signature doesn't verify
     */
    public Claims parseAccessToken(String token) {
        try {
            return Jwts.parser().verifyWith(key).build()
                    .parseSignedClaims(token)
                    .getPayload();
        } catch (ExpiredJwtException ex) {
            throw new TokenExpiredException("Access token expired");
        } catch (JwtException | IllegalArgumentException ex) {
            throw new InvalidTokenException("Invalid access token");
        }
    }

    public Long extractUserId(Claims claims) {
        return Long.parseLong(claims.getSubject());
    }

    @SuppressWarnings("unchecked")
    public Set<Role> extractRoles(Claims claims) {
        List<String> raw = claims.get("roles", List.class);
        if (raw == null) {
            return Set.of();
        }
        return raw.stream().map(Role::valueOf).collect(Collectors.toUnmodifiableSet());
    }

    public long accessTokenTtlSeconds() {
        return properties.accessTokenTtl().toSeconds();
    }

    public Duration refreshTokenTtl() {
        return properties.refreshTokenTtl();
    }
}

package com.lifey.auth;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Set;

/**
 * Verifies the access token {@code lifey-api} issued.
 *
 * <p>Named <em>Verifier</em>, not {@code JwtService}, because the asymmetry is
 * the design: this service has no {@code generateAccessToken}, no refresh-token
 * table, and no way to hand anyone a credential. If a chat bug ever wanted to
 * mint a token, it would have to add the capability first — which is a code
 * review, not an accident (§5.3).
 *
 * <p><b>The contract with lifey-api</b>, which must be changed on both sides in
 * the same deploy:
 * <ul>
 *   <li>algorithm HS256, shared secret</li>
 *   <li>{@code sub} — the user id, as a decimal string</li>
 *   <li>{@code email} — string</li>
 *   <li>{@code roles} — array of role names</li>
 *   <li>{@code iss} — {@code lifey.jwt.issuer}</li>
 * </ul>
 */
@Service
@EnableConfigurationProperties(JwtProperties.class)
public class JwtVerifier {

    private final SecretKey key;
    private final String issuer;

    public JwtVerifier(JwtProperties properties) {
        this.key = Keys.hmacShaKeyFor(properties.secret().getBytes(StandardCharsets.UTF_8));
        this.issuer = properties.issuer();
    }

    /**
     * @throws TokenExpiredException if the signature is valid but the token has expired
     * @throws InvalidTokenException if it is malformed, signed with another key,
     *                               or issued by someone else
     */
    public UserPrincipal verify(String token) {
        Claims claims;
        try {
            claims = Jwts.parser()
                    .verifyWith(key)
                    .requireIssuer(issuer)
                    .build()
                    .parseSignedClaims(token)
                    .getPayload();
        } catch (ExpiredJwtException _) {
            throw new TokenExpiredException("Access token expired");
        } catch (JwtException | IllegalArgumentException _) {
            throw new InvalidTokenException("Invalid access token");
        }
        return principalOf(claims);
    }

    private static UserPrincipal principalOf(Claims claims) {
        return new UserPrincipal(
                Long.parseLong(claims.getSubject()),
                claims.get("email", String.class),
                rolesOf(claims));
    }

    /**
     * Roles stay strings (see {@link UserPrincipal}). A token with no roles
     * claim is a valid token belonging to someone with no elevated access —
     * which is every ordinary user of the chat.
     */
    @SuppressWarnings("unchecked")
    private static Set<String> rolesOf(Claims claims) {
        List<String> raw = claims.get("roles", List.class);
        return raw == null ? Set.of() : Set.copyOf(raw);
    }
}

package com.lifey.auth;

import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;

import java.util.Collection;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * Who the bearer token says is calling.
 *
 * <p>Narrower than the monolith's class of the same name, and deliberately so.
 * This service <b>only ever verifies</b> a token that {@code lifey-api} issued
 * (§5.3); it never authenticates anyone from a password and never looks a user
 * up to log them in. So there is no {@code UserDetails}, no password hash, and
 * no {@code Role} enum — the roles stay the raw strings from the {@code roles}
 * claim.
 *
 * <p>Not mirroring the enum is the point: adding a role over there must not
 * require a release over here. An unknown role name simply becomes an authority
 * nothing grants access to, instead of an {@code IllegalArgumentException} out
 * of {@code Role.valueOf} that would reject the whole request.
 */
public record UserPrincipal(Long id, String email, Set<String> roles) {

    public UserPrincipal {
        roles = Set.copyOf(roles);
    }

    public Collection<? extends GrantedAuthority> getAuthorities() {
        return roles.stream()
                .map(SimpleGrantedAuthority::new)
                .collect(Collectors.toUnmodifiableSet());
    }
}

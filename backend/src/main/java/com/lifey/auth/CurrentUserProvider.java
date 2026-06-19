package com.lifey.auth;

import org.springframework.security.authentication.InsufficientAuthenticationException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;

/**
 * Resolves the authenticated user id from Spring Security's context. Services
 * inject this directly rather than accepting a userId parameter or depending on
 * the servlet request — see docs/09-auth-module.md for the reasoning (in short:
 * it keeps ownership-scoping in the service layer, where the filtering actually
 * happens, without coupling services to the web layer).
 */
@Component
public class CurrentUserProvider {

    public Long getUserId() {
        return principal().id();
    }

    private UserPrincipal principal() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated() || !(auth.getPrincipal() instanceof UserPrincipal principal)) {
            throw new InsufficientAuthenticationException("No authenticated user in the current request");
        }
        return principal;
    }
}

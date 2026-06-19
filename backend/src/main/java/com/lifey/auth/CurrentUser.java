package com.lifey.auth;

import org.springframework.security.core.annotation.AuthenticationPrincipal;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Injects the authenticated {@link UserPrincipal} into a controller method
 * parameter, e.g. {@code findMine(@CurrentUser UserPrincipal user)}. A thin,
 * named alias over Spring Security's {@code @AuthenticationPrincipal} (which
 * supports being used as a meta-annotation) so call sites don't repeat a SpEL
 * expression or cast.
 * Most controllers in this app don't need this: they delegate straight to a
 * service, and services resolve the user themselves via {@link CurrentUserProvider}.
 * Reach for {@code @CurrentUser} only when a controller itself needs the
 * principal — e.g. a future {@code GET /api/v1/users/me} profile endpoint.
 */
@Target(ElementType.PARAMETER)
@Retention(RetentionPolicy.RUNTIME)
@AuthenticationPrincipal
public @interface CurrentUser {
}

package com.lifey.auth;

import com.lifey.auth.service.JwtService;
import io.jsonwebtoken.Claims;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.jspecify.annotations.NonNull;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

/**
 * Authenticates each request from its {@code Authorization: Bearer <token>}
 * header, if present. On a token problem (expired/invalid), this filter does
 * NOT reject the request itself — it leaves the security context unauthenticated
 * and stashes the specific exception as a request attribute so
 * {@link JwtAuthenticationEntryPoint} can report it precisely once Spring
 * Security's exception-translation machinery rejects the (protected) request.
 * Deliberately NOT a {@code @Component}: this class implements {@code Filter}
 * (via {@code OncePerRequestFilter}), and Spring Boot auto-registers any bean of
 * that type into the servlet container's global filter chain — on top of it
 * already running inside Spring Security's chain via {@code addFilterBefore}.
 * That would run it twice per request. Instantiating it directly in
 * {@link SecurityConfig} avoids it ever becoming a bean.
 */
@RequiredArgsConstructor
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    public static final String AUTH_ERROR_ATTRIBUTE = "lifey.auth.error";

    private final JwtService jwtService;

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    @NonNull HttpServletResponse response,
                                    @NonNull FilterChain filterChain) throws ServletException, IOException {
        String header = request.getHeader("Authorization");
        if (header != null && header.startsWith("Bearer ")) {
            String token = header.substring(7);
            try {
                Claims claims = jwtService.parseAccessToken(token);
                UserPrincipal principal = new UserPrincipal(
                        jwtService.extractUserId(claims),
                        claims.get("email", String.class),
                        "",
                        jwtService.extractRoles(claims));
                var authentication = new UsernamePasswordAuthenticationToken(
                        principal, null, principal.getAuthorities());
                authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
                SecurityContextHolder.getContext().setAuthentication(authentication);
            } catch (RuntimeException ex) {
                SecurityContextHolder.clearContext();
                request.setAttribute(AUTH_ERROR_ATTRIBUTE, ex);
            }
        }
        filterChain.doFilter(request, response);
    }
}

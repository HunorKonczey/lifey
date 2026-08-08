package com.lifey.internal;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.lifey.common.exception.ApiError;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.jspecify.annotations.NonNull;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.List;

/**
 * Guards {@code /internal/**}: service-to-service calls from {@code lifey-chat},
 * authenticated by a shared secret rather than a user token
 * (docs/chat/44-chat-service-extraction-plan.md §5.5).
 *
 * <p>These endpoints act <em>on behalf of</em> a user without one being signed
 * in — {@code POST /internal/push} sends a notification to an arbitrary user id
 * — so the secret is the only thing between the internet and a notification
 * spammer. Two consequences:
 *
 * <ul>
 *   <li>Comparison is <b>constant time</b> ({@link MessageDigest#isEqual}).
 *       {@code String.equals} short-circuits on the first differing byte, which
 *       leaks the secret one character at a time to anyone willing to measure.</li>
 *   <li>A missing configured secret <b>closes</b> the endpoint rather than
 *       opening it. A deployment that forgot the variable loses push, which is
 *       noticed; the other default would be silently unauthenticated.</li>
 * </ul>
 *
 * <p>Deliberately NOT a {@code @Component} — Spring Boot would auto-register any
 * {@code Filter} bean into the container's global chain, on top of it already
 * running inside the {@code /internal/**} security chain. Same reasoning as
 * {@code JwtAuthenticationFilter}.
 */
@Slf4j
@RequiredArgsConstructor
public class InternalAuthFilter extends OncePerRequestFilter {

    static final String TOKEN_HEADER = "X-Lifey-Internal";

    private final InternalApiProperties properties;
    private final ObjectMapper objectMapper;

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    @NonNull HttpServletResponse response,
                                    @NonNull FilterChain filterChain) throws ServletException, IOException {
        if (!isAuthorized(request)) {
            // Path only, never the presented value — a rejected secret in the
            // logs is still a secret somebody typed.
            log.warn("Rejected internal call to {}", request.getRequestURI());
            writeUnauthorized(request, response);
            return;
        }
        filterChain.doFilter(request, response);
    }

    private boolean isAuthorized(HttpServletRequest request) {
        if (!properties.isConfigured()) {
            return false;
        }
        String presented = request.getHeader(TOKEN_HEADER);
        if (presented == null) {
            return false;
        }
        return MessageDigest.isEqual(
                presented.getBytes(StandardCharsets.UTF_8),
                properties.token().getBytes(StandardCharsets.UTF_8));
    }

    /** The same {@link ApiError} shape as everything else in this API. */
    private void writeUnauthorized(HttpServletRequest request, HttpServletResponse response) throws IOException {
        ApiError body = new ApiError(Instant.now(), HttpStatus.UNAUTHORIZED.value(),
                HttpStatus.UNAUTHORIZED.getReasonPhrase(), "Invalid internal credentials",
                request.getRequestURI(), List.of());
        response.setStatus(HttpStatus.UNAUTHORIZED.value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        objectMapper.writeValue(response.getWriter(), body);
    }
}

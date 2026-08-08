package com.lifey.internal;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.lifey.chat.spi.http.InternalHeaders;
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
 * Guards this service's {@code /internal/**} endpoints — calls from
 * {@code lifey-api}, authenticated by a shared secret rather than a user token
 * (docs/chat/44-chat-service-extraction-plan.md §5.5).
 *
 * <p>Mirror image of the monolith's filter of the same name, and the same two
 * decisions: <b>constant-time</b> comparison, because {@code String.equals}
 * short-circuits on the first differing byte and leaks the secret to anyone
 * willing to measure; and an unconfigured secret <b>closes</b> the endpoint
 * rather than opening it.
 *
 * <p>What is behind it matters here: {@code /internal/relationships/revoked}
 * freezes a conversation. Left open, it would be a way for anyone to silence
 * any pair's chat.
 */
@Slf4j
@RequiredArgsConstructor
public class InternalAuthFilter extends OncePerRequestFilter {

    private final String expectedToken;
    private final ObjectMapper objectMapper;

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    @NonNull HttpServletResponse response,
                                    @NonNull FilterChain filterChain) throws ServletException, IOException {
        if (!isAuthorized(request)) {
            log.warn("Rejected internal call to {}", request.getRequestURI());
            writeUnauthorized(request, response);
            return;
        }
        filterChain.doFilter(request, response);
    }

    private boolean isAuthorized(HttpServletRequest request) {
        if (expectedToken == null || expectedToken.isBlank()) {
            return false;
        }
        String presented = request.getHeader(InternalHeaders.TOKEN_HEADER);
        if (presented == null) {
            return false;
        }
        return MessageDigest.isEqual(
                presented.getBytes(StandardCharsets.UTF_8),
                expectedToken.getBytes(StandardCharsets.UTF_8));
    }

    private void writeUnauthorized(HttpServletRequest request, HttpServletResponse response) throws IOException {
        ApiError body = new ApiError(Instant.now(), HttpStatus.UNAUTHORIZED.value(),
                HttpStatus.UNAUTHORIZED.getReasonPhrase(), "Invalid internal credentials",
                request.getRequestURI(), List.of());
        response.setStatus(HttpStatus.UNAUTHORIZED.value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        objectMapper.writeValue(response.getWriter(), body);
    }
}

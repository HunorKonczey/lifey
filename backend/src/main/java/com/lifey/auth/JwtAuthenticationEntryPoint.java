package com.lifey.auth;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.lifey.common.exception.ApiError;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.time.Instant;
import java.util.List;

/**
 * Writes the same {@link ApiError} shape {@code GlobalExceptionHandler} uses,
 * for authentication failures that happen before the request ever reaches a
 * controller (missing/invalid/expired token, or no token at all on a protected
 * route). Those never run through {@code @RestControllerAdvice}, since they're
 * rejected by the filter chain itself — this is the filter-chain equivalent.
 */
@Component
@RequiredArgsConstructor
public class JwtAuthenticationEntryPoint implements AuthenticationEntryPoint {

    private final ObjectMapper objectMapper;

    @Override
    public void commence(HttpServletRequest request, HttpServletResponse response,
                         AuthenticationException authException) throws IOException {
        String message = messageFor(request);
        ApiError body = new ApiError(Instant.now(), HttpStatus.UNAUTHORIZED.value(),
                HttpStatus.UNAUTHORIZED.getReasonPhrase(), message, request.getRequestURI(), List.of());

        response.setStatus(HttpStatus.UNAUTHORIZED.value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        objectMapper.writeValue(response.getWriter(), body);
    }

    private String messageFor(HttpServletRequest request) {
        Object attr = request.getAttribute(JwtAuthenticationFilter.AUTH_ERROR_ATTRIBUTE);
        if (attr instanceof RuntimeException ex) {
            return ex.getMessage();
        }
        return "Authentication required";
    }
}

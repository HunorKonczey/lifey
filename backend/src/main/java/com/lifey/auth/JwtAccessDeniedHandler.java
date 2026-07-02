package com.lifey.auth;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.lifey.common.exception.ApiError;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.jspecify.annotations.NonNull;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.time.Instant;
import java.util.List;

/**
 * Filter-chain-level counterpart to {@link JwtAuthenticationEntryPoint}: handles
 * an authenticated-but-not-authorized request (e.g. a role check failing) with
 * the same {@link ApiError} JSON shape the rest of the API uses.
 */
@Component
@RequiredArgsConstructor
public class JwtAccessDeniedHandler implements AccessDeniedHandler {

    private final ObjectMapper objectMapper;

    @Override
    public void handle(HttpServletRequest request, HttpServletResponse response,
                       @NonNull AccessDeniedException accessDeniedException) throws IOException {
        ApiError body = new ApiError(Instant.now(), HttpStatus.FORBIDDEN.value(),
                HttpStatus.FORBIDDEN.getReasonPhrase(), "Access denied", request.getRequestURI(), List.of());

        response.setStatus(HttpStatus.FORBIDDEN.value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        objectMapper.writeValue(response.getWriter(), body);
    }
}

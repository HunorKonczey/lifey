package com.lifey.common.exception;

import jakarta.servlet.http.HttpServletRequest;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import java.time.Instant;
import java.util.List;

/**
 * Builds the {@link ApiError} response body and logs the outcome.
 *
 * <p>Extracted from {@link GlobalExceptionHandler} so a feature can own its own
 * {@code @RestControllerAdvice} without either duplicating the response shape or
 * forcing the global handler to import that feature's exceptions — which is what
 * the chat does (docs/chat/44-chat-service-extraction-plan.md §2.2). Every error
 * response in the API still comes out of exactly one place.
 */
@Slf4j
public final class ApiErrorResponses {

    private ApiErrorResponses() {
    }

    public static ResponseEntity<ApiError> build(HttpStatus status, String message,
                                                 HttpServletRequest request, List<String> details, Exception ex) {
        if (status.is5xxServerError()) {
            log.error("{} {} -> {} {}", request.getMethod(), request.getRequestURI(), status.value(), message, ex);
        } else {
            // 4xx responses are expected, client-driven outcomes (validation, auth, not-found
            // while onboarding, etc.) — log a one-liner without the stack trace to keep logs quiet.
            log.warn("{} {} -> {} {}", request.getMethod(), request.getRequestURI(), status.value(), message);
        }
        ApiError body = new ApiError(
                Instant.now(),
                status.value(),
                status.getReasonPhrase(),
                message,
                request.getRequestURI(),
                details
        );
        return ResponseEntity.status(status).body(body);
    }
}

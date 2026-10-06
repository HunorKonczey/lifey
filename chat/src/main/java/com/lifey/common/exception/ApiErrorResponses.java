package com.lifey.common.exception;

import jakarta.servlet.http.HttpServletRequest;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.ErrorResponse;

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

    /**
     * A failure Spring MVC itself raised — wrong HTTP method (405), unsupported or
     * unacceptable media type (415 / 406), ... — already knows its own status and
     * the headers that go with it ({@code Allow}, {@code Accept}). Without this the
     * catch-all turns every one of them into a 500 "unexpected error".
     */
    public static ResponseEntity<ApiError> framework(ErrorResponse error, HttpServletRequest request, Exception ex) {
        HttpStatus status = HttpStatus.resolve(error.getStatusCode().value());
        if (status == null) {
            status = HttpStatus.INTERNAL_SERVER_ERROR;
        }
        String detail = error.getBody().getDetail();
        ResponseEntity<ApiError> built =
                build(status, detail == null || detail.isBlank() ? status.getReasonPhrase() : detail, request, List.of(), ex);
        return ResponseEntity.status(status).headers(error.getHeaders()).body(built.getBody());
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

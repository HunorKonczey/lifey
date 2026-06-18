package com.lifey.common.exception;

import java.time.Instant;
import java.util.List;

/**
 * Standard error response payload.
 */
public record ApiError(
        Instant timestamp,
        int status,
        String error,
        String message,
        String path,
        List<String> details
) {
}

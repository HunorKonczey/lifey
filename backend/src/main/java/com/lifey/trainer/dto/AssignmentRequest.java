package com.lifey.trainer.dto;

import com.lifey.trainer.ContentType;
import jakarta.validation.constraints.NotNull;

public record AssignmentRequest(
        @NotNull
        Long clientId,

        @NotNull
        ContentType contentType,

        @NotNull
        Long sourceId
) {
}

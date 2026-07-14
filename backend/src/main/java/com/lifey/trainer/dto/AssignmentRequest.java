package com.lifey.trainer.dto;

import com.lifey.trainer.ContentType;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.List;

public record AssignmentRequest(
        /* May contain duplicates (deduped server-side); a single client is a bulk of one. */
        @NotEmpty
        @Size(max = 100)
        List<@NotNull Long> clientIds,

        @NotNull
        ContentType contentType,

        @NotNull
        Long sourceId
) {
}

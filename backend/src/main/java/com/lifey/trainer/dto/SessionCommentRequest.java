package com.lifey.trainer.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record SessionCommentRequest(
        @NotBlank
        @Size(max = 2000)
        String comment
) {
}

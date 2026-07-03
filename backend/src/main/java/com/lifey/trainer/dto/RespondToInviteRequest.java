package com.lifey.trainer.dto;

import jakarta.validation.constraints.NotNull;

public record RespondToInviteRequest(
        @NotNull
        Boolean accept
) {
}

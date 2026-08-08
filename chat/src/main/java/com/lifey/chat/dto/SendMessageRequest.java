package com.lifey.chat.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * @param body            plain text; the configurable upper bound lives in
 *                        {@code ChatProperties.maxBodyLength} and is checked
 *                        after trimming, so it isn't repeated as an annotation here
 * @param clientMessageId caller-generated id (a UUID in practice) making the
 *                        send idempotent; 64 is the column width, not a policy
 */
public record SendMessageRequest(
        @NotBlank String body,
        @NotBlank @Size(max = 64) String clientMessageId
) {
}

package com.lifey.chat.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * @param body            plain text, or the optional caption of a card; the
 *                        configurable upper bound lives in
 *                        {@code ChatProperties.maxBodyLength} and is checked
 *                        after trimming, so it isn't repeated as an annotation
 *                        here. Not {@code @NotBlank}: a card is a complete
 *                        message without one, so "body or card" is the service's
 *                        rule (docs/chat/83-chat-result-card-plan.md §3)
 * @param clientMessageId caller-generated id (a UUID in practice) making the
 *                        send idempotent; 64 is the column width, not a policy
 * @param card            a shared workout or personal record, or null
 */
public record SendMessageRequest(
        String body,
        @NotBlank @Size(max = 64) String clientMessageId,
        @Valid MessageCard card
) {
}

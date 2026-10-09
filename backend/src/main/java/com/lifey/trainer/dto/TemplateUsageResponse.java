package com.lifey.trainer.dto;

import java.util.List;

/**
 * Who uses one of the trainer's workout templates (LIF-106): the clients it was assigned to, and the clients who have it
 * in a schedule or a program that is still running. A client can be in both; the lists are ids, the page knows the names.
 */
public record TemplateUsageResponse(
        Long templateId,
        List<Long> assignedClientIds,
        List<Long> scheduledClientIds
) {
}

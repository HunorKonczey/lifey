package com.lifey.trainer.dto;

import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;
import java.time.LocalTime;

/**
 * The new slot of one scheduled occurrence (drag-to-move on the trainer calendar). It is the whole slot, not a patch of
 * one field: a null {@code scheduledTime} means "no time of day", so moving a 18:00 workout onto a day without a time
 * is expressed by sending the day and no time.
 */
public record MoveOccurrenceRequest(

        @NotNull
        LocalDate scheduledFor,

        /* Optional wall-clock time of the new slot. */
        LocalTime scheduledTime
) {
}

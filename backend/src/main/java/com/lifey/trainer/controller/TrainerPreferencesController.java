package com.lifey.trainer.controller;

import com.lifey.settings.service.SettingsService;
import com.lifey.trainer.dto.TrainerPreferencesRequest;
import com.lifey.trainer.dto.TrainerPreferencesResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * The trainer's own preferences — the weekly report email opt-out
 * (docs/33-weekly-trainer-report-plan.md) and the two client pushes
 * (docs/85-trainer-push-plan.md). Deliberately separate from
 * {@code /settings}: that endpoint is the mobile client-settings round-trip,
 * this one is trainer-only and web-only.
 */
@Tag(name = "Trainer Preferences", description = "The trainer's own preferences (not client data)")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/trainer/preferences")
public class TrainerPreferencesController {

    private final SettingsService settingsService;

    @Operation(summary = "Current trainer's preferences")
    @GetMapping
    public TrainerPreferencesResponse get() {
        return current();
    }

    @Operation(summary = "Update the current trainer's preferences")
    @PutMapping
    public TrainerPreferencesResponse update(@Valid @RequestBody TrainerPreferencesRequest request) {
        if (request.weeklyReportEmailEnabled() != null) {
            settingsService.setWeeklyReportEmailEnabled(request.weeklyReportEmailEnabled());
        }
        if (request.clientMissedWorkoutPushEnabled() != null) {
            settingsService.setClientMissedWorkoutPushEnabled(request.clientMissedWorkoutPushEnabled());
        }
        if (request.clientWeighInPushEnabled() != null) {
            settingsService.setClientWeighInPushEnabled(request.clientWeighInPushEnabled());
        }
        return current();
    }

    private TrainerPreferencesResponse current() {
        return new TrainerPreferencesResponse(
                settingsService.isWeeklyReportEmailEnabled(),
                settingsService.isClientMissedWorkoutPushEnabled(),
                settingsService.isClientWeighInPushEnabled());
    }
}

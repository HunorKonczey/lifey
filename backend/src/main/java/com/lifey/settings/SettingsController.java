package com.lifey.settings;

import com.lifey.settings.dto.SettingsRequest;
import com.lifey.settings.dto.SettingsResponse;
import com.lifey.settings.service.SettingsService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@Tag(name = "Settings", description = "Per-user preferences: units, daily goals, theme")
@RequiredArgsConstructor
@RestController
@RequestMapping("/api/v1/settings")
public class SettingsController {

    private final SettingsService settingsService;

    @Operation(summary = "Get the current user's settings (created with defaults on first access)")
    @GetMapping
    public SettingsResponse get() {
        return settingsService.get();
    }

    @Operation(summary = "Replace the current user's settings")
    @PutMapping
    public SettingsResponse update(@Valid @RequestBody SettingsRequest request) {
        return settingsService.update(request);
    }
}

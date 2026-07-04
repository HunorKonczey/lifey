package com.lifey.userdetails;

import com.lifey.userdetails.dto.SuggestGoalsRequest;
import com.lifey.userdetails.dto.SuggestGoalsResponse;
import com.lifey.userdetails.dto.UserDetailsPatchRequest;
import com.lifey.userdetails.dto.UserDetailsRequest;
import com.lifey.userdetails.dto.UserDetailsResponse;
import com.lifey.userdetails.service.UserDetailsService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@Tag(name = "User Details", description = "Onboarding biometrics and suggested daily goals")
@RestController
@RequestMapping("/api/v1/user-details")
@RequiredArgsConstructor
public class UserDetailsController {

    private final UserDetailsService userDetailsService;

    @Operation(summary = "Get the current user's onboarding details",
            description = "404 if the user hasn't completed onboarding yet.")
    @GetMapping
    public UserDetailsResponse get() {
        return userDetailsService.get();
    }

    @Operation(summary = "Upsert the current user's onboarding details",
            description = "Used both for the initial onboarding submit and later edits from Settings.")
    @PutMapping
    public UserDetailsResponse update(@Valid @RequestBody UserDetailsRequest request) {
        return userDetailsService.upsert(request);
    }

    @Operation(summary = "Partially update the current user's onboarding details",
            description = "Persists only the selected fields (see UserDetailsPatchRequest.fields) and "
                    + "recalculates + applies the daily calorie/macro/water goals to settings. "
                    + "Used by the Settings edit confirmation popup.")
    @PatchMapping
    public UserDetailsResponse partialUpdate(@Valid @RequestBody UserDetailsPatchRequest request) {
        return userDetailsService.partialUpdate(request);
    }

    @Operation(summary = "Compute suggested daily calorie/macro/water goals",
            description = "Stateless — computed from the request body, nothing is persisted, "
                    + "so the wizard can preview goals before the user commits to anything.")
    @PostMapping("/suggest-goals")
    public SuggestGoalsResponse suggestGoals(@Valid @RequestBody SuggestGoalsRequest request) {
        return userDetailsService.suggestGoals(request);
    }
}

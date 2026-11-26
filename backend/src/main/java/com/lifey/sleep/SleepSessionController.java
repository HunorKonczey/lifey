package com.lifey.sleep;

import com.lifey.sleep.dto.SleepSessionRequest;
import com.lifey.sleep.dto.SleepSessionResponse;
import com.lifey.sleep.service.SleepSessionService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;

@Tag(name = "Sleep", description = "Sleep sessions imported from the health store (docs/integrations/89 M2)")
@RestController
@RequestMapping("/api/v1/sleep-sessions")
@RequiredArgsConstructor
public class SleepSessionController {

    private final SleepSessionService sleepSessionService;

    @Operation(summary = "List sleep sessions (newest end first)")
    @GetMapping(params = "!updatedSince")
    public List<SleepSessionResponse> findAll() {
        return sleepSessionService.findAll();
    }

    @Operation(summary = "Delta-sync feed of sleep sessions",
            description = "Backs the mobile offline sync pull (see docs/16-delta-sync-rollout.md). "
                    + "`updatedSince` (ISO-8601 instant) is required; ordering is fixed to "
                    + "updatedAt,id ascending, and a non-null `deletedAt` on a returned row is a "
                    + "tombstone. Response is a standard Spring Data page.")
    @GetMapping(params = "updatedSince")
    public Page<SleepSessionResponse> findDelta(
            @PageableDefault(size = 200) Pageable pageable,
            @Parameter(description = "ISO-8601 instant — switches to the delta-sync feed")
            @RequestParam Instant updatedSince) {
        return sleepSessionService.findDelta(updatedSince, pageable);
    }

    @Operation(summary = "Add a sleep session",
            description = "409 when the user already has a session for the same `healthRecordId`, "
                    + "a deleted one included.")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public SleepSessionResponse create(@Valid @RequestBody SleepSessionRequest request) {
        return sleepSessionService.create(request);
    }

    @Operation(summary = "Delete a sleep session")
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        sleepSessionService.delete(id);
    }
}

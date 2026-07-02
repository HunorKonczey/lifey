package com.lifey.water;

import com.lifey.water.dto.WaterEntryRequest;
import com.lifey.water.dto.WaterEntryResponse;
import com.lifey.water.service.WaterEntryService;
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

@Tag(name = "Water Entries", description = "Logged water intake (manual or from a water source)")
@RestController
@RequestMapping("/api/v1/water-entries")
@RequiredArgsConstructor
public class WaterEntryController {

    private final WaterEntryService waterEntryService;

    @Operation(summary = "List all water entries (newest first)")
    @GetMapping(params = "!updatedSince")
    public List<WaterEntryResponse> findAll() {
        return waterEntryService.findAll();
    }

    @Operation(summary = "Delta-sync feed of water entries",
            description = "Backs the mobile offline sync pull (see docs/16-delta-sync-rollout.md). "
                    + "`updatedSince` (ISO-8601 instant) is required; ordering is fixed to "
                    + "updatedAt,id ascending, and a non-null `deletedAt` on a returned row is a "
                    + "tombstone. Response is a standard Spring Data page.")
    @GetMapping(params = "updatedSince")
    public Page<WaterEntryResponse> findDelta(
            @PageableDefault(size = 200) Pageable pageable,
            @Parameter(description = "ISO-8601 instant — switches to the delta-sync feed")
            @RequestParam Instant updatedSince) {
        return waterEntryService.findDelta(updatedSince, pageable);
    }

    @Operation(summary = "Log water intake, optionally from a water source")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public WaterEntryResponse create(@Valid @RequestBody WaterEntryRequest request) {
        return waterEntryService.create(request);
    }

    @Operation(summary = "Delete a water entry")
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        waterEntryService.delete(id);
    }
}

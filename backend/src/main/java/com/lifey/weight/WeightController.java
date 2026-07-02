package com.lifey.weight;

import com.lifey.weight.dto.WeightRequest;
import com.lifey.weight.dto.WeightResponse;
import com.lifey.weight.service.WeightService;
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

@Tag(name = "Weight Tracking", description = "Daily body-weight entries")
@RestController
@RequestMapping("/api/v1/weights")
@RequiredArgsConstructor
public class WeightController {

    private final WeightService weightService;

    @Operation(summary = "List all weight entries (newest first)")
    @GetMapping(params = "!updatedSince")
    public List<WeightResponse> findAll() {
        return weightService.findAll();
    }

    @Operation(summary = "Delta-sync feed of weight entries",
            description = "Backs the mobile offline sync pull (see docs/16-delta-sync-rollout.md). "
                    + "`updatedSince` (ISO-8601 instant) is required; ordering is fixed to "
                    + "updatedAt,id ascending, and a non-null `deletedAt` on a returned row is a "
                    + "tombstone. Response is a standard Spring Data page.")
    @GetMapping(params = "updatedSince")
    public Page<WeightResponse> findDelta(
            @PageableDefault(size = 200) Pageable pageable,
            @Parameter(description = "ISO-8601 instant — switches to the delta-sync feed")
            @RequestParam Instant updatedSince) {
        return weightService.findDelta(updatedSince, pageable);
    }

    @Operation(summary = "Add a weight entry")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public WeightResponse create(@Valid @RequestBody WeightRequest request) {
        return weightService.create(request);
    }

    @Operation(summary = "Delete a weight entry")
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        weightService.delete(id);
    }
}

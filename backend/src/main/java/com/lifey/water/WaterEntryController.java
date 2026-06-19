package com.lifey.water;

import com.lifey.water.dto.WaterEntryRequest;
import com.lifey.water.dto.WaterEntryResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@Tag(name = "Water Entries", description = "Logged water intake (manual or from a water source)")
@RestController
@RequestMapping("/api/v1/water-entries")
public class WaterEntryController {

    private final WaterEntryService waterEntryService;

    public WaterEntryController(WaterEntryService waterEntryService) {
        this.waterEntryService = waterEntryService;
    }

    @Operation(summary = "List all water entries (newest first)")
    @GetMapping
    public List<WaterEntryResponse> findAll() {
        return waterEntryService.findAll();
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

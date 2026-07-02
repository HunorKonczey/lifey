package com.lifey.water;

import com.lifey.water.dto.WaterSourceRequest;
import com.lifey.water.dto.WaterSourceResponse;
import com.lifey.water.service.WaterSourceService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@Tag(name = "Water Sources", description = "Reusable water-intake presets (e.g. \"Creatine Shake\" = 0.9L)")
@RestController
@RequestMapping("/api/v1/water-sources")
@RequiredArgsConstructor
public class WaterSourceController {

    private final WaterSourceService waterSourceService;

    @Operation(summary = "List all water sources")
    @GetMapping
    public List<WaterSourceResponse> findAll() {
        return waterSourceService.findAll();
    }

    @Operation(summary = "Get a water source")
    @GetMapping("/{id}")
    public WaterSourceResponse findById(@PathVariable Long id) {
        return waterSourceService.findById(id);
    }

    @Operation(summary = "Create a water source")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public WaterSourceResponse create(@Valid @RequestBody WaterSourceRequest request) {
        return waterSourceService.create(request);
    }

    @Operation(summary = "Update a water source")
    @PutMapping("/{id}")
    public WaterSourceResponse update(@PathVariable Long id, @Valid @RequestBody WaterSourceRequest request) {
        return waterSourceService.update(id, request);
    }

    @Operation(summary = "Delete a water source")
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        waterSourceService.delete(id);
    }
}

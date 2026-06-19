package com.lifey.water;

import com.lifey.water.dto.WaterSourceRequest;
import com.lifey.water.dto.WaterSourceResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@Tag(name = "Water Sources", description = "Reusable water-intake presets (e.g. \"Creatine Shake\" = 0.9L)")
@RestController
@RequestMapping("/api/v1/water-sources")
public class WaterSourceController {

    private final WaterSourceService waterSourceService;

    public WaterSourceController(WaterSourceService waterSourceService) {
        this.waterSourceService = waterSourceService;
    }

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

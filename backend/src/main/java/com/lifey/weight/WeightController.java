package com.lifey.weight;

import com.lifey.weight.dto.WeightRequest;
import com.lifey.weight.dto.WeightResponse;
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

@Tag(name = "Weight Tracking", description = "Daily body-weight entries")
@RestController
@RequestMapping("/api/v1/weights")
public class WeightController {

    private final WeightService weightService;

    public WeightController(WeightService weightService) {
        this.weightService = weightService;
    }

    @Operation(summary = "List all weight entries (newest first)")
    @GetMapping
    public List<WeightResponse> findAll() {
        return weightService.findAll();
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

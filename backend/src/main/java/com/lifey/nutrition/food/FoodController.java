package com.lifey.nutrition.food;

import com.lifey.nutrition.food.dto.BarcodeLookupResponse;
import com.lifey.nutrition.food.dto.FoodRequest;
import com.lifey.nutrition.food.dto.FoodResponse;
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

@Tag(name = "Foods", description = "Manage foods and their per-100g macros")
@RestController
@RequestMapping("/api/v1/foods")
public class FoodController {

    private final FoodService foodService;
    private final BarcodeLookupService barcodeLookupService;

    public FoodController(FoodService foodService, BarcodeLookupService barcodeLookupService) {
        this.foodService = foodService;
        this.barcodeLookupService = barcodeLookupService;
    }

    @Operation(summary = "List all foods")
    @GetMapping
    public List<FoodResponse> findAll() {
        return foodService.findAll();
    }

    @Operation(summary = "Get a food by id")
    @GetMapping("/{id}")
    public FoodResponse findById(@PathVariable Long id) {
        return foodService.findById(id);
    }

    @Operation(summary = "Create a food")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public FoodResponse create(@Valid @RequestBody FoodRequest request) {
        return foodService.create(request);
    }

    @Operation(summary = "Update a food")
    @PutMapping("/{id}")
    public FoodResponse update(@PathVariable Long id, @Valid @RequestBody FoodRequest request) {
        return foodService.update(id, request);
    }

    @Operation(summary = "Look up a food by barcode",
            description = "Returns the existing catalog entry if one is already tagged with this "
                    + "barcode (source=LOCAL), otherwise queries OpenFoodFacts (source=OPENFOODFACTS). "
                    + "The OpenFoodFacts result is not persisted — POST /foods to save it.")
    @GetMapping("/barcode/{barcode}")
    public BarcodeLookupResponse findByBarcode(@PathVariable String barcode) {
        return barcodeLookupService.lookup(barcode);
    }

    @Operation(summary = "Delete a food")
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        foodService.delete(id);
    }
}

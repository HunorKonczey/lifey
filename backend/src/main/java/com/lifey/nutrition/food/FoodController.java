package com.lifey.nutrition.food;

import com.lifey.nutrition.food.dto.BarcodeLookupResponse;
import com.lifey.nutrition.food.dto.FoodRequest;
import com.lifey.nutrition.food.dto.FoodResponse;
import com.lifey.nutrition.food.service.BarcodeLookupService;
import com.lifey.nutrition.food.service.FoodService;
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

@Tag(name = "Foods", description = "Manage foods and their per-100g macros")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/foods")
public class FoodController {

    private final FoodService foodService;
    private final BarcodeLookupService barcodeLookupService;

    @Operation(summary = "List all foods",
            description = "Unpaged: always returns the full catalog. Kept for backward compatibility "
                    + "with existing callers (e.g. the mobile offline sync pull migrating to /foods?page=...). "
                    + "Any request carrying a `page` param is routed to the paged handler below instead.")
    @GetMapping(params = "!page")
    public List<FoodResponse> findAll() {
        return foodService.findAll();
    }

    @Operation(summary = "List foods, paged and optionally searched or delta-synced",
            description = "Backs the web foods table and the mobile offline sync pull. `search` "
                    + "case-insensitively matches on name; omit it to page through everything. "
                    + "`updatedSince` (ISO-8601 instant) switches to the delta-sync feed (see "
                    + "docs/15-delta-sync.md): `search` is ignored, hidden/deleted rows are included, "
                    + "and ordering is fixed to updatedAt,id ascending; a non-null `deletedAt` on a "
                    + "returned row is a tombstone. Response is a standard Spring Data page: content, "
                    + "totalElements, totalPages, number, size, last, ...")
    @GetMapping(params = "page")
    public Page<FoodResponse> findPage(
            @PageableDefault(size = 200, sort = {"name", "id"}) Pageable pageable,
            @Parameter(description = "Case-insensitive name contains-match")
            @RequestParam(required = false) String search,
            @Parameter(description = "ISO-8601 instant — switches to the delta-sync feed")
            @RequestParam(required = false) Instant updatedSince) {
        return foodService.findPage(pageable, search, updatedSince);
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

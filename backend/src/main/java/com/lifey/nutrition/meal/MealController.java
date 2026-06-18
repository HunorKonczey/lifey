package com.lifey.nutrition.meal;

import com.lifey.nutrition.meal.dto.MealRequest;
import com.lifey.nutrition.meal.dto.MealResponse;
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

@Tag(name = "Meals", description = "Log meals with food entries")
@RestController
@RequestMapping("/api/v1/meals")
public class MealController {

    private final MealService mealService;

    public MealController(MealService mealService) {
        this.mealService = mealService;
    }

    @Operation(summary = "List all meals (newest first)")
    @GetMapping
    public List<MealResponse> findAll() {
        return mealService.findAll();
    }

    @Operation(summary = "Log a meal")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public MealResponse create(@Valid @RequestBody MealRequest request) {
        return mealService.create(request);
    }

    @Operation(summary = "Update a meal")
    @PutMapping("/{id}")
    public MealResponse update(@PathVariable Long id, @Valid @RequestBody MealRequest request) {
        return mealService.update(id, request);
    }

    @Operation(summary = "Delete a meal")
    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable Long id) {
        mealService.delete(id);
    }
}

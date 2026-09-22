package com.lifey.nutrition.estimation;

import com.lifey.nutrition.estimation.dto.MealEstimateResponse;
import com.lifey.nutrition.estimation.service.MealEstimationService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@Tag(name = "Meal Estimation", description = "AI calorie estimation from a meal photo")
@RestController
@RequestMapping("/api/v1/meals/estimate")
@RequiredArgsConstructor
public class MealEstimationController {

    private final MealEstimationService service;

    @Operation(summary = "Estimate the foods and nutrition in a meal photo",
            description = "Accepts a JPEG/PNG photo up to 10MB. Returns the recognized items with "
                    + "portion grams and calories/macros for that portion; nothing is stored. An empty "
                    + "items list means no food was recognized. 402 AI_CREDITS_EXHAUSTED when this "
                    + "month's AI allowance is used up, 502 AI_UNAVAILABLE when the model call fails "
                    + "(no credit is used), 503 AI_NOT_CONFIGURED when the server has no API key.")
    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public MealEstimateResponse estimate(@RequestParam("image") MultipartFile image) {
        return service.estimate(image);
    }
}

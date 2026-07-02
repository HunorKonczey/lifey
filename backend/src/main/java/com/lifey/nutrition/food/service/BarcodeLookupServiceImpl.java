package com.lifey.nutrition.food.service;

import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.nutrition.food.Food;
import com.lifey.nutrition.food.FoodRepository;
import com.lifey.nutrition.food.dto.BarcodeLookupResponse;
import com.lifey.nutrition.food.dto.BarcodeSource;
import com.lifey.nutrition.openfoodfacts.OffProduct;
import com.lifey.nutrition.openfoodfacts.client.OpenFoodFactsClient;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class BarcodeLookupServiceImpl implements BarcodeLookupService {

    private final FoodRepository foodRepository;
    private final OpenFoodFactsClient openFoodFactsClient;

    @Override
    public BarcodeLookupResponse lookup(String barcode) {
        return foodRepository.findByBarcode(barcode)
                .map(this::toLocalResponse)
                .orElseGet(() -> lookupOnOpenFoodFacts(barcode));
    }

    private BarcodeLookupResponse lookupOnOpenFoodFacts(String barcode) {
        OffProduct product = openFoodFactsClient.findByBarcode(barcode)
                .filter(this::hasUsableNutrition)
                .orElseThrow(() -> new ResourceNotFoundException("No food found for barcode: " + barcode));

        return new BarcodeLookupResponse(
                null,
                product.name() != null ? product.name() : "",
                product.energyKcalPer100g(),
                product.proteinsPer100g(),
                product.carbohydratesPer100g(),
                product.fatPer100g(),
                barcode,
                BarcodeSource.OPENFOODFACTS
        );
    }

    /**
     * OpenFoodFacts entries are community-submitted and often incomplete; without
     * at least calories and protein the result isn't worth prefilling a food with.
     */
    private boolean hasUsableNutrition(OffProduct product) {
        return product.energyKcalPer100g() != null && product.proteinsPer100g() != null;
    }

    private BarcodeLookupResponse toLocalResponse(Food food) {
        return new BarcodeLookupResponse(
                food.getId(),
                food.getName(),
                food.getCaloriesPer100g(),
                food.getProteinPer100g(),
                food.getCarbsPer100g(),
                food.getFatPer100g(),
                food.getBarcode(),
                BarcodeSource.LOCAL
        );
    }
}

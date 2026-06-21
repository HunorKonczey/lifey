package com.lifey.nutrition.food;

import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.nutrition.food.dto.BarcodeLookupResponse;
import com.lifey.nutrition.food.dto.BarcodeSource;
import com.lifey.nutrition.openfoodfacts.OffProduct;
import com.lifey.nutrition.openfoodfacts.OpenFoodFactsClient;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class BarcodeLookupServiceImplTest {

    @Mock
    FoodRepository foodRepository;

    @Mock
    OpenFoodFactsClient openFoodFactsClient;

    @InjectMocks
    BarcodeLookupServiceImpl service;

    @Test
    void lookup_returnsLocalFoodWhenBarcodeAlreadyInCatalog() {
        when(foodRepository.findByBarcode("5901234123457")).thenReturn(Optional.of(food()));

        BarcodeLookupResponse result = service.lookup("5901234123457");

        assertThat(result.id()).isEqualTo(1L);
        assertThat(result.name()).isEqualTo("Chicken");
        assertThat(result.caloriesPer100g()).isEqualTo(165.0);
        assertThat(result.source()).isEqualTo(BarcodeSource.LOCAL);
        verify(openFoodFactsClient, never()).findByBarcode(any(String.class));
    }

    @Test
    void lookup_returnsOpenFoodFactsResultWhenNotInCatalog() {
        when(foodRepository.findByBarcode("5901234123457")).thenReturn(Optional.empty());
        when(openFoodFactsClient.findByBarcode("5901234123457"))
                .thenReturn(Optional.of(new OffProduct("Cola", "Acme", 42.0, 0.0, 10.6, 0.0)));

        BarcodeLookupResponse result = service.lookup("5901234123457");

        assertThat(result.id()).isNull();
        assertThat(result.name()).isEqualTo("Cola");
        assertThat(result.caloriesPer100g()).isEqualTo(42.0);
        assertThat(result.barcode()).isEqualTo("5901234123457");
        assertThat(result.source()).isEqualTo(BarcodeSource.OPENFOODFACTS);
    }

    @Test
    void lookup_throwsWhenOpenFoodFactsHasNoProduct() {
        when(foodRepository.findByBarcode("0000000000000")).thenReturn(Optional.empty());
        when(openFoodFactsClient.findByBarcode("0000000000000")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.lookup("0000000000000"))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void lookup_throwsWhenOpenFoodFactsProductLacksUsableNutrition() {
        when(foodRepository.findByBarcode("1111111111111")).thenReturn(Optional.empty());
        when(openFoodFactsClient.findByBarcode("1111111111111"))
                .thenReturn(Optional.of(new OffProduct("Mystery item", "Acme", null, null, null, null)));

        assertThatThrownBy(() -> service.lookup("1111111111111"))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    private static Food food() {
        Food f = new Food();
        f.setId(1L);
        f.setName("Chicken");
        f.setCaloriesPer100g(165.0);
        f.setProteinPer100g(31.0);
        f.setBarcode("5901234123457");
        return f;
    }
}

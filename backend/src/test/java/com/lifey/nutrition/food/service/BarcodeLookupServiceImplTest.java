package com.lifey.nutrition.food.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.nutrition.food.Food;
import com.lifey.nutrition.food.FoodRepository;
import com.lifey.nutrition.food.dto.BarcodeLookupResponse;
import com.lifey.nutrition.food.dto.BarcodeSource;
import com.lifey.nutrition.openfoodfacts.OffProduct;
import com.lifey.nutrition.openfoodfacts.client.OpenFoodFactsClient;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class BarcodeLookupServiceImplTest {

    private static final Long USER_ID = 42L;

    @Mock
    FoodRepository foodRepository;

    @Mock
    OpenFoodFactsClient openFoodFactsClient;

    @Mock
    CurrentUserProvider currentUserProvider;

    @InjectMocks
    BarcodeLookupServiceImpl service;

    @BeforeEach
    void setUp() {
        when(currentUserProvider.getUserId()).thenReturn(USER_ID);
    }

    @Test
    void lookup_returnsLocalFoodWhenBarcodeAlreadyInCatalog() {
        when(foodRepository.findByUserIdAndBarcode(USER_ID, "5901234123457")).thenReturn(Optional.of(food()));

        BarcodeLookupResponse result = service.lookup("5901234123457");

        assertThat(result.id()).isEqualTo(1L);
        assertThat(result.name()).isEqualTo("Chicken");
        assertThat(result.caloriesPer100g()).isEqualTo(165.0);
        assertThat(result.source()).isEqualTo(BarcodeSource.LOCAL);
        verify(openFoodFactsClient, never()).findByBarcode(any(String.class));
    }

    @Test
    void lookup_returnsOpenFoodFactsResultWhenNotInCatalog() {
        when(foodRepository.findByUserIdAndBarcode(USER_ID, "5901234123457")).thenReturn(Optional.empty());
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
    void lookup_fallsBackToEmptyNameWhenOpenFoodFactsOmitsProductName() {
        when(foodRepository.findByUserIdAndBarcode(USER_ID, "8586022215544")).thenReturn(Optional.empty());
        when(openFoodFactsClient.findByBarcode("8586022215544"))
                .thenReturn(Optional.of(new OffProduct(null, "Acme", 42.0, 0.0, 10.6, 0.0)));

        BarcodeLookupResponse result = service.lookup("8586022215544");

        assertThat(result.name()).isEmpty();
    }

    @Test
    void lookup_throwsWhenOpenFoodFactsHasNoProduct() {
        when(foodRepository.findByUserIdAndBarcode(USER_ID, "0000000000000")).thenReturn(Optional.empty());
        when(openFoodFactsClient.findByBarcode("0000000000000")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.lookup("0000000000000"))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void lookup_throwsWhenOpenFoodFactsProductLacksUsableNutrition() {
        when(foodRepository.findByUserIdAndBarcode(USER_ID, "1111111111111")).thenReturn(Optional.empty());
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

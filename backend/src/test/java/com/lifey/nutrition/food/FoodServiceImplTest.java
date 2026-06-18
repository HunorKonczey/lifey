package com.lifey.nutrition.food;

import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.nutrition.food.dto.FoodRequest;
import com.lifey.nutrition.food.dto.FoodResponse;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class FoodServiceImplTest {

    @Mock
    FoodRepository repository;

    @InjectMocks
    FoodServiceImpl service;

    @Test
    void findAll_mapsFoods() {
        when(repository.findAll()).thenReturn(List.of(food(1L, "Chicken", 165, 31)));

        List<FoodResponse> result = service.findAll();

        assertThat(result).singleElement().satisfies(r -> {
            assertThat(r.id()).isEqualTo(1L);
            assertThat(r.name()).isEqualTo("Chicken");
            assertThat(r.caloriesPer100g()).isEqualTo(165.0);
            assertThat(r.proteinPer100g()).isEqualTo(31.0);
        });
    }

    @Test
    void findById_returnsFood() {
        when(repository.findById(1L)).thenReturn(Optional.of(food(1L, "Chicken", 165, 31)));

        assertThat(service.findById(1L).name()).isEqualTo("Chicken");
    }

    @Test
    void findById_throwsWhenMissing() {
        when(repository.findById(99L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.findById(99L))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void create_savesAndReturnsResponse() {
        FoodRequest request = new FoodRequest("Rice", 130.0, 2.7, null, null);
        when(repository.save(any(Food.class))).thenAnswer(inv -> {
            Food f = inv.getArgument(0);
            f.setId(7L);
            return f;
        });

        FoodResponse result = service.create(request);

        assertThat(result.id()).isEqualTo(7L);
        assertThat(result.name()).isEqualTo("Rice");
        assertThat(result.carbsPer100g()).isNull();
    }

    @Test
    void update_appliesChangesToExistingFood() {
        Food existing = food(3L, "Old", 100, 10);
        when(repository.findById(3L)).thenReturn(Optional.of(existing));
        FoodRequest request = new FoodRequest("New", 200.0, 25.0, 5.0, 1.0);

        FoodResponse result = service.update(3L, request);

        assertThat(result.id()).isEqualTo(3L);
        assertThat(result.name()).isEqualTo("New");
        assertThat(result.caloriesPer100g()).isEqualTo(200.0);
        assertThat(existing.getName()).isEqualTo("New");
    }

    @Test
    void update_throwsWhenMissing() {
        when(repository.findById(99L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.update(99L, new FoodRequest("X", 1.0, 1.0, null, null)))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void delete_throwsWhenMissing() {
        when(repository.existsById(99L)).thenReturn(false);

        assertThatThrownBy(() -> service.delete(99L))
                .isInstanceOf(ResourceNotFoundException.class);
        verify(repository, never()).deleteById(any());
    }

    private static Food food(Long id, String name, double cal, double protein) {
        Food f = new Food();
        f.setId(id);
        f.setName(name);
        f.setCaloriesPer100g(cal);
        f.setProteinPer100g(protein);
        return f;
    }
}

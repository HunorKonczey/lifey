package com.lifey.nutrition.food;

import com.lifey.common.exception.DuplicateResourceException;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.nutrition.food.dto.FoodRequest;
import com.lifey.nutrition.food.dto.FoodResponse;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
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
        when(repository.findAllByHiddenFalseOrderByName()).thenReturn(List.of(food(1L, "Chicken", 165, 31)));

        List<FoodResponse> result = service.findAll();

        assertThat(result).singleElement().satisfies(r -> {
            assertThat(r.id()).isEqualTo(1L);
            assertThat(r.name()).isEqualTo("Chicken");
            assertThat(r.caloriesPer100g()).isEqualTo(165.0);
            assertThat(r.proteinPer100g()).isEqualTo(31.0);
        });
    }

    @Test
    void findAll_excludesHiddenFoods() {
        when(repository.findAllByHiddenFalseOrderByName()).thenReturn(List.of());

        assertThat(service.findAll()).isEmpty();
    }

    @Test
    void findPage_noSearch_usesHiddenFalseQuery() {
        Pageable pageable = PageRequest.of(0, 2);
        Page<Food> page = new PageImpl<>(List.of(food(1L, "Chicken", 165, 31)), pageable, 1);
        when(repository.findByHiddenFalse(pageable)).thenReturn(page);

        Page<FoodResponse> result = service.findPage(pageable, null, null);

        assertThat(result.getTotalElements()).isEqualTo(1);
        assertThat(result.getContent()).singleElement()
                .satisfies(r -> assertThat(r.name()).isEqualTo("Chicken"));
        verify(repository, never()).findByHiddenFalseAndNameContainingIgnoreCase(any(), any());
    }

    @Test
    void findPage_blankSearch_treatedAsNoSearch() {
        Pageable pageable = PageRequest.of(0, 2);
        when(repository.findByHiddenFalse(pageable)).thenReturn(Page.empty(pageable));

        service.findPage(pageable, "   ", null);

        verify(repository).findByHiddenFalse(pageable);
        verify(repository, never()).findByHiddenFalseAndNameContainingIgnoreCase(any(), any());
    }

    @Test
    void findPage_sortedByNullableColumn_forcesNullsLast() {
        Pageable requested = PageRequest.of(0, 10, org.springframework.data.domain.Sort.by(
                org.springframework.data.domain.Sort.Direction.DESC, "fatPer100g"));
        when(repository.findByHiddenFalse(any())).thenReturn(Page.empty(requested));

        service.findPage(requested, null, null);

        org.mockito.ArgumentCaptor<Pageable> captor = org.mockito.ArgumentCaptor.forClass(Pageable.class);
        verify(repository).findByHiddenFalse(captor.capture());
        org.springframework.data.domain.Sort.Order order = captor.getValue().getSort().getOrderFor("fatPer100g");
        assertThat(order).isNotNull();
        assertThat(order.getDirection()).isEqualTo(org.springframework.data.domain.Sort.Direction.DESC);
        assertThat(order.getNullHandling()).isEqualTo(org.springframework.data.domain.Sort.NullHandling.NULLS_LAST);
    }

    @Test
    void findPage_unsorted_leavesPageableUntouched() {
        Pageable unsorted = PageRequest.of(0, 10);
        when(repository.findByHiddenFalse(unsorted)).thenReturn(Page.empty(unsorted));

        service.findPage(unsorted, null, null);

        verify(repository).findByHiddenFalse(unsorted);
    }

    @Test
    void findPage_withSearch_usesSearchQueryAndTrimsIt() {
        Pageable pageable = PageRequest.of(0, 10);
        Page<Food> page = new PageImpl<>(List.of(food(2L, "Rice", 130, 2.7)), pageable, 1);
        when(repository.findByHiddenFalseAndNameContainingIgnoreCase(eq("rice"), eq(pageable)))
                .thenReturn(page);

        Page<FoodResponse> result = service.findPage(pageable, "  rice  ", null);

        assertThat(result.getContent()).singleElement()
                .satisfies(r -> assertThat(r.name()).isEqualTo("Rice"));
        verify(repository, never()).findByHiddenFalse(any());
    }

    @Test
    void findPage_withUpdatedSince_usesDeltaQueryIgnoringSearchAndForcesOrdering() {
        Pageable requested = PageRequest.of(0, 200);
        Instant since = Instant.parse("2026-06-01T00:00:00Z");
        Food deleted = food(4L, "Old Rice", 130, 2.7);
        deleted.setDeletedAt(Instant.parse("2026-06-15T00:00:00Z"));
        when(repository.findByUpdatedAtGreaterThanEqual(eq(since), any()))
                .thenReturn(new PageImpl<>(List.of(deleted), requested, 1));

        Page<FoodResponse> result = service.findPage(requested, "should be ignored", since);

        assertThat(result.getContent()).singleElement()
                .satisfies(r -> assertThat(r.deletedAt()).isEqualTo(deleted.getDeletedAt()));
        verify(repository, never()).findByHiddenFalse(any());
        verify(repository, never()).findByHiddenFalseAndNameContainingIgnoreCase(any(), any());

        org.mockito.ArgumentCaptor<Pageable> captor = org.mockito.ArgumentCaptor.forClass(Pageable.class);
        verify(repository).findByUpdatedAtGreaterThanEqual(eq(since), captor.capture());
        org.springframework.data.domain.Sort sort = captor.getValue().getSort();
        assertThat(sort.getOrderFor("updatedAt").getDirection())
                .isEqualTo(org.springframework.data.domain.Sort.Direction.ASC);
        assertThat(sort.getOrderFor("id").getDirection())
                .isEqualTo(org.springframework.data.domain.Sort.Direction.ASC);
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
        FoodRequest request = new FoodRequest("Rice", 130.0, 2.7, null, null, null, false);
        when(repository.findByNameIgnoreCase("Rice")).thenReturn(Optional.empty());
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
    void create_throwsWhenNameAlreadyExists() {
        FoodRequest request = new FoodRequest(" Rice ", 130.0, 2.7, null, null, null, false);
        when(repository.findByNameIgnoreCase("Rice")).thenReturn(Optional.of(food(1L, "Rice", 130, 2.7)));

        assertThatThrownBy(() -> service.create(request))
                .isInstanceOf(DuplicateResourceException.class);
        verify(repository, never()).save(any());
    }

    @Test
    void update_appliesChangesToExistingFood() {
        Food existing = food(3L, "Old", 100, 10);
        when(repository.findById(3L)).thenReturn(Optional.of(existing));
        when(repository.findByNameIgnoreCase("New")).thenReturn(Optional.empty());
        FoodRequest request = new FoodRequest("New", 200.0, 25.0, 5.0, 1.0, null, false);

        FoodResponse result = service.update(3L, request);

        assertThat(result.id()).isEqualTo(3L);
        assertThat(result.name()).isEqualTo("New");
        assertThat(result.caloriesPer100g()).isEqualTo(200.0);
        assertThat(existing.getName()).isEqualTo("New");
    }

    @Test
    void update_allowsKeepingItsOwnName() {
        Food existing = food(3L, "Rice", 100, 10);
        when(repository.findById(3L)).thenReturn(Optional.of(existing));
        when(repository.findByNameIgnoreCase("Rice")).thenReturn(Optional.of(existing));
        FoodRequest request = new FoodRequest("Rice", 110.0, 10.0, null, null, null, false);

        FoodResponse result = service.update(3L, request);

        assertThat(result.caloriesPer100g()).isEqualTo(110.0);
    }

    @Test
    void update_throwsWhenNameTakenByAnotherFood() {
        Food existing = food(3L, "Old", 100, 10);
        when(repository.findById(3L)).thenReturn(Optional.of(existing));
        when(repository.findByNameIgnoreCase("Rice")).thenReturn(Optional.of(food(9L, "Rice", 130, 2.7)));

        assertThatThrownBy(() -> service.update(3L, new FoodRequest("Rice", 200.0, 25.0, null, null, null, false)))
                .isInstanceOf(DuplicateResourceException.class);
    }

    @Test
    void update_throwsWhenMissing() {
        when(repository.findById(99L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.update(99L, new FoodRequest("X", 1.0, 1.0, null, null, null, false)))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void delete_softDeletesFoodAndSetsTombstone() {
        Food food = food(5L, "Banana", 89, 1.1);
        when(repository.findById(5L)).thenReturn(Optional.of(food));

        service.delete(5L);

        assertThat(food.isHidden()).isTrue();
        assertThat(food.getDeletedAt()).isNotNull();
        verify(repository, never()).delete(any());
    }

    @Test
    void delete_throwsWhenMissing() {
        when(repository.findById(99L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.delete(99L))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void create_hiddenFoodSkipsNameCheck() {
        FoodRequest request = new FoodRequest("Rice", 130.0, 2.7, null, null, null, true);
        when(repository.save(any(Food.class))).thenAnswer(inv -> {
            Food f = inv.getArgument(0);
            f.setId(8L);
            return f;
        });

        FoodResponse result = service.create(request);

        assertThat(result.id()).isEqualTo(8L);
        verify(repository, never()).findByNameIgnoreCase(any());
    }

    @Test
    void create_hiddenExistingFoodDoesNotBlock() {
        FoodRequest request = new FoodRequest("Rice", 130.0, 2.7, null, null, null, false);
        Food hiddenRice = food(1L, "Rice", 130, 2.7);
        hiddenRice.setHidden(true);
        when(repository.findByNameIgnoreCase("Rice")).thenReturn(Optional.of(hiddenRice));
        when(repository.save(any(Food.class))).thenAnswer(inv -> {
            Food f = inv.getArgument(0);
            f.setId(9L);
            return f;
        });

        FoodResponse result = service.create(request);

        assertThat(result.id()).isEqualTo(9L);
    }

    @Test
    void update_hiddenFoodSkipsNameCheck() {
        Food existing = food(3L, "Old", 100, 10);
        when(repository.findById(3L)).thenReturn(Optional.of(existing));
        FoodRequest request = new FoodRequest("Rice", 200.0, 25.0, null, null, null, true);

        service.update(3L, request);

        verify(repository, never()).findByNameIgnoreCase(any());
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

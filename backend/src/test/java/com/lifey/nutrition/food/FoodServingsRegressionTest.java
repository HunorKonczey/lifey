package com.lifey.nutrition.food;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.nutrition.food.dto.FoodRequest;
import com.lifey.nutrition.food.dto.FoodResponse;
import com.lifey.nutrition.food.dto.FoodServingRequest;
import com.lifey.nutrition.food.dto.FoodServingResponse;
import com.lifey.nutrition.food.service.FoodService;
import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.data.domain.PageRequest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import java.time.Instant;
import java.util.HashSet;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

/**
 * Named serving sizes (LIF-146) against a real database: the {@code food_servings} table keeps the order they were given in,
 * a page of foods carries them, a save that changes only the servings moves {@code updatedAt} (delta sync), and a client that
 * knows nothing about servings cannot erase them with an ordinary update.
 */
@SpringBootTest
@Testcontainers
class FoodServingsRegressionTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    @Autowired
    FoodService foodService;

    @Autowired
    UserRepository userRepository;

    @MockitoBean
    CurrentUserProvider currentUserProvider;

    private User owner;

    @BeforeEach
    void seed() {
        owner = new User();
        owner.setEmail("servings-" + System.nanoTime() + "@example.com");
        owner.setPasswordHash("irrelevant");
        owner.setCreatedAt(Instant.now());
        owner.setRoles(new HashSet<>(List.of(Role.ROLE_USER)));
        owner = userRepository.save(owner);
        when(currentUserProvider.getUserId()).thenReturn(owner.getId());
    }

    private static FoodRequest milk(String name, List<FoodServingRequest> servings) {
        return new FoodRequest(name, 46.0, 3.4, 4.8, 1.5, null, false, null, null, servings);
    }

    @Test
    void theServingsComeBackInTheOrderTheyWereGiven() {
        FoodResponse created = foodService.create(milk("Milk " + System.nanoTime(),
                List.of(new FoodServingRequest("1 glass", 200.0), new FoodServingRequest("1 spoon", 15.0), new FoodServingRequest("1 cup", 250.0))));

        FoodResponse reloaded = foodService.findById(created.id());

        assertThat(reloaded.servings()).extracting(FoodServingResponse::name).containsExactly("1 glass", "1 spoon", "1 cup");
        assertThat(reloaded.servings()).extracting(FoodServingResponse::grams).containsExactly(200.0, 15.0, 250.0);
    }

    @Test
    void theFavouriteMark_isStored_survivesAnOrdinaryUpdate_andMovesUpdatedAt() throws InterruptedException {
        String name = "Fav " + System.nanoTime();
        FoodResponse created = foodService.create(new FoodRequest(name, 46.0, 3.4, 4.8, 1.5, null, false, null, null, null, true));
        assertThat(foodService.findById(created.id()).favorite()).isTrue();

        // A client that does not know the field: the star stays.
        Thread.sleep(20);
        FoodResponse ordinary = foodService.update(created.id(), new FoodRequest(name, 50.0, 3.4, 4.8, 1.5, null, false));
        assertThat(ordinary.favorite()).isTrue();

        // Only the star changes: the food must still reach the phones' delta sync.
        Thread.sleep(20);
        FoodResponse before = foodService.findById(created.id());
        FoodResponse off = foodService.update(created.id(), new FoodRequest(name, 50.0, 3.4, 4.8, 1.5, null, false, null, null, null, false));
        assertThat(off.favorite()).isFalse();
        assertThat(foodService.findById(created.id()).updatedAt()).isAfter(before.updatedAt());
        assertThat(foodService.findPage(PageRequest.of(0, 50), null, before.updatedAt()).getContent())
                .anySatisfy(f -> {
                    assertThat(f.id()).isEqualTo(created.id());
                    assertThat(f.favorite()).isFalse();
                });
    }

    @Test
    void aPageOfFoodsCarriesTheirServings() {
        String tag = "Page" + System.nanoTime();
        FoodResponse a = foodService.create(milk(tag + " a", List.of(new FoodServingRequest("1 glass", 200.0))));
        FoodResponse b = foodService.create(milk(tag + " b", List.of()));

        List<FoodResponse> page = foodService.findPage(PageRequest.of(0, 10), tag, null).getContent();

        assertThat(page).hasSize(2);
        assertThat(page.stream().filter(f -> f.id().equals(a.id())).findFirst().orElseThrow().servings()).hasSize(1);
        assertThat(page.stream().filter(f -> f.id().equals(b.id())).findFirst().orElseThrow().servings()).isEmpty();
    }

    @Test
    void updatingOnlyTheServings_movesUpdatedAt_andAnOrdinaryUpdateKeepsThem() throws InterruptedException {
        String name = "Keep " + System.nanoTime();
        FoodResponse created = foodService.create(milk(name, List.of(new FoodServingRequest("1 glass", 200.0))));

        Thread.sleep(20);
        FoodResponse servingsOnly = foodService.update(created.id(), milk(name, List.of(new FoodServingRequest("1 glass", 200.0), new FoodServingRequest("1 cup", 250.0))));
        assertThat(servingsOnly.servings()).hasSize(2);
        assertThat(foodService.findById(created.id()).updatedAt()).isAfter(created.updatedAt());

        // The phone before it learned servings: no servings field at all.
        FoodResponse ordinary = foodService.update(created.id(), new FoodRequest(name, 50.0, 3.4, 4.8, 1.5, null, false));
        assertThat(ordinary.servings()).extracting(FoodServingResponse::name).containsExactly("1 glass", "1 cup");

        FoodResponse cleared = foodService.update(created.id(), milk(name, List.of()));
        assertThat(cleared.servings()).isEmpty();
        assertThat(foodService.findById(created.id()).servings()).isEmpty();
    }
}

package com.lifey.nutrition.food;

import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.dao.DataIntegrityViolationException;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import java.time.Instant;
import java.util.HashSet;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * V82: a deleted food no longer holds its barcode, against a real Postgres. Before it, scanning a product the
 * user had once deleted could not be saved again (409 on every attempt), and everything logged with the new
 * food waited behind that failed create. The index still has to refuse two <em>live</em> foods with one barcode.
 */
@SpringBootTest
@Testcontainers
class FoodBarcodeLiveUniqueRepositoryTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    @Autowired
    UserRepository userRepository;

    @Autowired
    FoodRepository foodRepository;

    User user;
    String barcode;

    @BeforeEach
    void seed() {
        User created = new User();
        created.setEmail("barcode-live-" + System.nanoTime() + "@example.com");
        created.setPasswordHash("irrelevant");
        created.setCreatedAt(Instant.now());
        created.setRoles(new HashSet<>(List.of(Role.ROLE_USER)));
        user = userRepository.save(created);
        barcode = "B" + System.nanoTime();
    }

    @Test
    void aDeletedFoodDoesNotBlockSavingTheSameBarcodeAgain() {
        Food deleted = foodRepository.saveAndFlush(food("Milk", Instant.now()));
        Food again = foodRepository.saveAndFlush(food("Milk (new)", null));

        assertThat(foodRepository.findByUserIdAndBarcodeAndDeletedAtIsNull(user.getId(), barcode))
                .get().extracting(Food::getId).isEqualTo(again.getId()).isNotEqualTo(deleted.getId());
    }

    @Test
    void aDeletedFoodAloneIsNotFoundByItsBarcode() {
        foodRepository.saveAndFlush(food("Milk", Instant.now()));

        assertThat(foodRepository.findByUserIdAndBarcodeAndDeletedAtIsNull(user.getId(), barcode)).isEmpty();
    }

    @Test
    void twoLiveFoodsStillCannotShareABarcode() {
        foodRepository.saveAndFlush(food("Milk", null));

        assertThatThrownBy(() -> foodRepository.saveAndFlush(food("Milk 2", null)))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    private Food food(String name, Instant deletedAt) {
        Food food = new Food();
        food.setUser(user);
        food.setName(name);
        food.setCaloriesPer100g(60);
        food.setProteinPer100g(3);
        food.setBarcode(barcode);
        food.setDeletedAt(deletedAt);
        // A tombstone is hidden too, so its name does not collide with the live "Milk" under foods_name_unique_idx.
        food.setHidden(deletedAt != null);
        return food;
    }
}

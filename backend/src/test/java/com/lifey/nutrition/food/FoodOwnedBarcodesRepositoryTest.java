package com.lifey.nutrition.food;

import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import java.time.Instant;
import java.util.HashSet;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * {@link FoodRepository#findOwnedBarcodes} against a real Postgres (docs/84 D6): the name search drops
 * OpenFoodFacts hits the user already has as a food. Like the accent regression test, a mocked repository
 * can never catch a broken JPQL, a missing user scope or a tombstone leaking through.
 */
@SpringBootTest
@Testcontainers
class FoodOwnedBarcodesRepositoryTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    @Autowired
    UserRepository userRepository;

    @Autowired
    FoodRepository foodRepository;

    Long userId;
    Long otherUserId;
    String run;

    @BeforeEach
    void seed() {
        User user = newUser("owned-barcodes-a-");
        User other = newUser("owned-barcodes-b-");
        userId = user.getId();
        otherUserId = other.getId();

        // One shared container: every seed uses barcodes of its own.
        String run = String.valueOf(System.nanoTime());
        food(user, "Live", "L" + run, null);
        food(user, "Deleted", "D" + run, Instant.now());
        food(user, "No barcode", null, null);
        food(other, "Someone else's", "O" + run, null);
        this.run = run;
    }

    @Test
    void returnsOnlyTheUsersLiveBarcodesAmongTheOnesAsked() {
        var owned = foodRepository.findOwnedBarcodes(userId, List.of("L" + run, "D" + run, "O" + run, "X" + run));

        assertThat(owned).containsExactly("L" + run);
    }

    @Test
    void anotherUserSeesOnlyTheirOwn() {
        var owned = foodRepository.findOwnedBarcodes(otherUserId, List.of("L" + run, "O" + run));

        assertThat(owned).containsExactly("O" + run);
    }

    @Test
    void nothingAskedForFindsNothing() {
        assertThat(foodRepository.findOwnedBarcodes(userId, List.of("Z" + run))).isEmpty();
    }

    private User newUser(String prefix) {
        User user = new User();
        user.setEmail(prefix + System.nanoTime() + "@example.com");
        user.setPasswordHash("irrelevant");
        user.setCreatedAt(Instant.now());
        user.setRoles(new HashSet<>(List.of(Role.ROLE_USER)));
        return userRepository.save(user);
    }

    private void food(User owner, String name, String barcode, Instant deletedAt) {
        Food food = new Food();
        food.setUser(owner);
        food.setName(name);
        food.setCaloriesPer100g(100);
        food.setProteinPer100g(10);
        food.setBarcode(barcode);
        food.setDeletedAt(deletedAt);
        foodRepository.save(food);
    }
}

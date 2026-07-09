package com.lifey.nutrition.food;

import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.data.domain.PageRequest;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.time.Instant;
import java.util.HashSet;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Regression test for accent-insensitive search (FoodRepository's
 * {@code function('unaccent', ...)} query) — a plain @Mock-backed service
 * test never sends the query through Hibernate/Postgres, so it can't catch a
 * broken {@code unaccent()} passthrough or a missing extension
 * (V47__unaccent_search.sql). This is the real DB round-trip.
 */
@SpringBootTest
@Testcontainers
class FoodSearchAccentRegressionTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>("postgres:16");

    @Autowired
    UserRepository userRepository;

    @Autowired
    FoodRepository foodRepository;

    Long userId;

    @BeforeEach
    void seedUserAndFood() {
        User user = new User();
        user.setEmail("food-search-accent-" + System.nanoTime() + "@example.com");
        user.setPasswordHash("irrelevant");
        user.setCreatedAt(Instant.now());
        user.setRoles(new HashSet<>(List.of(Role.ROLE_USER)));
        userId = userRepository.save(user).getId();

        Food food = new Food();
        food.setUser(user);
        food.setName("Kolbász");
        food.setCaloriesPer100g(300);
        food.setProteinPer100g(15);
        foodRepository.save(food);
    }

    @Test
    void unaccentedQuery_matchesAccentedName() {
        var result = foodRepository.findByUserIdAndHiddenFalseAndNameContainingIgnoreCase(
                userId, "kolbasz", PageRequest.of(0, 10));

        assertThat(result.getContent()).extracting(Food::getName).containsExactly("Kolbász");
    }

    @Test
    void accentedQuery_matchesUnaccentedTyping() {
        var result = foodRepository.findByUserIdAndHiddenFalseAndNameContainingIgnoreCase(
                userId, "kOlB", PageRequest.of(0, 10));

        assertThat(result.getContent()).extracting(Food::getName).containsExactly("Kolbász");
    }
}

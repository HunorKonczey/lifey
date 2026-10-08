package com.lifey.nutrition.meal;

import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.data.domain.PageRequest;
import org.springframework.transaction.support.TransactionTemplate;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import java.time.Instant;
import java.util.HashSet;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * The trainer's comment on a meal (LIF-144) goes through V84, is stored on the meal, and — because the meal is
 * delta-synced — makes it reappear in the client's next pull: writing the comment bumps {@code updatedAt}.
 */
@SpringBootTest
@Testcontainers
class MealTrainerCommentRegressionTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    @Autowired
    UserRepository userRepository;

    @Autowired
    MealRepository mealRepository;

    @Autowired
    TransactionTemplate transactionTemplate;

    @Test
    void aTrainerCommentIsStoredAndPutsTheMealBackInTheClientsDelta() {
        User client = new User();
        client.setEmail("meal-comment-client-" + System.nanoTime() + "@example.com");
        client.setPasswordHash("irrelevant");
        client.setCreatedAt(Instant.now());
        client.setRoles(new HashSet<>(List.of(Role.ROLE_USER)));
        client = userRepository.save(client);

        Meal meal = new Meal();
        meal.setUser(client);
        meal.setDateTime(Instant.parse("2026-06-01T12:00:00Z"));
        meal.setMealType(MealType.LUNCH);
        Long mealId = mealRepository.save(meal).getId();
        Long clientId = client.getId();
        Instant afterCreate = mealRepository.findById(mealId).orElseThrow().getUpdatedAt();

        // The client already pulled everything up to now ...
        Instant since = afterCreate.plusMillis(1);
        assertThat(mealRepository.findByUserIdAndUpdatedAtGreaterThanEqual(clientId, since, PageRequest.of(0, 50)).getContent())
                .isEmpty();

        // ... then the trainer comments.
        transactionTemplate.executeWithoutResult(status -> {
            Meal managed = mealRepository.findByIdAndUserId(mealId, clientId).orElseThrow();
            managed.setTrainerComment("More greens");
            managed.setTrainerCommentAt(Instant.now());
            managed.setTrainerCommentBy(clientId);
        });

        Meal reloaded = mealRepository.findByIdAndUserId(mealId, clientId).orElseThrow();
        assertThat(reloaded.getTrainerComment()).isEqualTo("More greens");
        assertThat(reloaded.getTrainerCommentAt()).isNotNull();
        assertThat(reloaded.getUpdatedAt()).isAfter(afterCreate);
        assertThat(mealRepository.findByUserIdAndUpdatedAtGreaterThanEqual(clientId, since, PageRequest.of(0, 50)).getContent())
                .extracting(Meal::getId).containsExactly(mealId);
    }
}

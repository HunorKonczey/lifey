package com.lifey.statistics;

import com.lifey.nutrition.food.Food;
import com.lifey.nutrition.food.FoodRepository;
import com.lifey.nutrition.meal.Meal;
import com.lifey.nutrition.meal.MealEntry;
import com.lifey.nutrition.meal.MealRepository;
import com.lifey.nutrition.meal.MealType;
import com.lifey.statistics.dto.StatisticsResponse;
import com.lifey.statistics.service.StatisticsService;
import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.HashSet;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.within;

/**
 * Fibre and sugars in the statistics (LIF-148) against a real database: the totals add up only the foods that have a figure
 * (an unknown one is not 0), are {@code null} when none has, and are flagged partial when some entries lack one.
 */
@SpringBootTest
@Testcontainers
class StatisticsFiberSugarRegressionTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    private static final LocalDate DAY = LocalDate.of(2026, 6, 10);
    private static final Instant NOON = DAY.atTime(12, 0).toInstant(ZoneOffset.UTC);

    @Autowired
    UserRepository userRepository;

    @Autowired
    FoodRepository foodRepository;

    @Autowired
    MealRepository mealRepository;

    @Autowired
    StatisticsService statisticsService;

    private User newUser() {
        User user = new User();
        user.setEmail("stats-fibre-" + System.nanoTime() + "@example.com");
        user.setPasswordHash("irrelevant");
        user.setCreatedAt(Instant.now());
        user.setUtcOffsetMinutes(0);
        user.setRoles(new HashSet<>(List.of(Role.ROLE_USER)));
        return userRepository.save(user);
    }

    private Food food(User owner, String name, Double fiber, Double sugar) {
        Food food = new Food();
        food.setUser(owner);
        food.setName(name + " " + System.nanoTime());
        food.setCaloriesPer100g(100);
        food.setProteinPer100g(5);
        food.setFiberPer100g(fiber);
        food.setSugarPer100g(sugar);
        return foodRepository.save(food);
    }

    /** One meal at {@code at} with the given foods, each eaten in the grams that follows it. */
    private void eat(User owner, Instant at, Object... foodAndGrams) {
        Meal meal = new Meal();
        meal.setUser(owner);
        meal.setDateTime(at);
        meal.setMealType(MealType.LUNCH);
        for (int i = 0; i < foodAndGrams.length; i += 2) {
            MealEntry entry = new MealEntry();
            entry.setMeal(meal);
            entry.setFood((Food) foodAndGrams[i]);
            entry.setQuantityInGrams(((Number) foodAndGrams[i + 1]).doubleValue());
            meal.getEntries().add(entry);
        }
        mealRepository.save(meal);
    }

    private StatisticsResponse daily(User user) {
        return statisticsService.dailyForUser(user.getId(), DAY);
    }

    @Test
    void totalsAddUpTheKnownFigures_scaledToTheGrams() {
        User user = newUser();
        eat(user, NOON, food(user, "Oats", 10.0, 1.0), 50, food(user, "Apple", 2.4, 10.0), 150);

        StatisticsResponse stats = daily(user);

        assertThat(stats.totalFiber()).isCloseTo(8.6, within(1e-9)); // 5 + 3.6
        assertThat(stats.totalSugar()).isCloseTo(15.5, within(1e-9)); // 0.5 + 15
        assertThat(stats.fiberSugarPartial()).isFalse();
    }

    @Test
    void noFoodWithAFigure_isNull_notZero_andNotPartial() {
        User user = newUser();
        eat(user, NOON, food(user, "Mystery", null, null), 100);

        StatisticsResponse stats = daily(user);

        assertThat(stats.totalFiber()).isNull();
        assertThat(stats.totalSugar()).isNull();
        assertThat(stats.fiberSugarPartial()).isFalse();
        assertThat(stats.totalCalories()).isEqualTo(100.0); // the rest of the response is unaffected
    }

    @Test
    void someFoodsWithoutAFigure_leaveTheKnownSum_andFlagItPartial() {
        User user = newUser();
        eat(user, NOON, food(user, "Oats", 10.0, 1.0), 100, food(user, "Mystery", null, null), 200,
                food(user, "Fibre only", 4.0, null), 100);

        StatisticsResponse stats = daily(user);

        assertThat(stats.totalFiber()).isCloseTo(14.0, within(1e-9)); // 10 + 4, the unknown food adds nothing
        assertThat(stats.totalSugar()).isCloseTo(1.0, within(1e-9));
        assertThat(stats.fiberSugarPartial()).isTrue();
    }

    @Test
    void aFoodKnownForFibreOnly_keepsFibre_leavesSugarNull_andIsPartial() {
        User user = newUser();
        eat(user, NOON, food(user, "Fibre only", 4.0, null), 100);

        StatisticsResponse stats = daily(user);

        assertThat(stats.totalFiber()).isCloseTo(4.0, within(1e-9));
        assertThat(stats.totalSugar()).isNull();
        assertThat(stats.fiberSugarPartial()).isTrue(); // that entry's sugar is not known
    }

    @Test
    void onlyThePeriodAndTheOwnersMealsCount() {
        User user = newUser();
        User other = newUser();
        Food oats = food(user, "Oats", 10.0, 1.0);
        eat(user, NOON, oats, 100);
        eat(user, DAY.minusDays(1).atTime(12, 0).toInstant(ZoneOffset.UTC), oats, 100); // yesterday
        eat(other, NOON, food(other, "Bran", 40.0, 2.0), 100); // someone else

        assertThat(daily(user).totalFiber()).isCloseTo(10.0, within(1e-9));
        assertThat(statisticsService.weeklyForUser(user.getId(), DAY).totalFiber()).isCloseTo(20.0, within(1e-9));
    }
}

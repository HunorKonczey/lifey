package com.lifey.migration;

import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;
import java.sql.Timestamp;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * V95__meal_entry_recipe.sql adds {@code meal_entries.recipe_id} and backfills it from meal names (docs/88 §2.6).
 * The backfill is a name match, so a wrong join silently tags the wrong recipe, and a missing {@code updated_at}
 * bump silently keeps the tags from every client (the delta feed pages by it) - neither shows in a unit test.
 *
 * <p>Migrates to V94, seeds meals around the rules, migrates to latest and checks: a unique live name is tagged
 * (case and spaces ignored) and its meal bumped, while an ambiguous name, a deleted recipe, an unnamed meal, a
 * deleted meal and another user's meal are left alone.
 */
@Testcontainers
class MealEntryRecipeMigrationTest {

    static final PostgreSQLContainer POSTGRES =
            new PostgreSQLContainer("postgres:16").withDatabaseName("lifey").withUsername("lifey").withPassword("lifey");

    static final Timestamp LONG_AGO = Timestamp.valueOf("2026-01-01 00:00:00");

    static Connection connection;

    static long userAId;
    static long userBId;
    static long userCId;
    static long chilliAId;
    static long chilliBId;
    static long uniqueNameMeal;
    static long ambiguousNameMeal;
    static long deletedRecipeMeal;
    static long unnamedMeal;
    static long deletedMeal;
    static long otherUserMeal;
    static long noRecipeUserMeal;

    @BeforeAll
    static void migrateToV94SeedAndMigrate() throws Exception {
        POSTGRES.start();

        Flyway.configure()
                .dataSource(POSTGRES.getJdbcUrl(), POSTGRES.getUsername(), POSTGRES.getPassword())
                .locations("classpath:db/migration")
                .target("94")
                .load()
                .migrate();

        connection = DriverManager.getConnection(POSTGRES.getJdbcUrl(), POSTGRES.getUsername(), POSTGRES.getPassword());
        connection.setAutoCommit(true);

        try (Statement st = connection.createStatement()) {
            userAId = insertUser(st, "a@example.com");
            userBId = insertUser(st, "b@example.com");
            userCId = insertUser(st, "c@example.com");
            long foodA = insertFood(st, userAId);
            long foodB = insertFood(st, userBId);
            long foodC = insertFood(st, userCId);

            chilliAId = insertRecipe(st, userAId, "Chilli", false);
            insertRecipe(st, userAId, "Soup", false);
            insertRecipe(st, userAId, "Soup", false);
            insertRecipe(st, userAId, "Gone", true);
            chilliBId = insertRecipe(st, userBId, "Chilli", false);

            // Name match ignores case and surrounding spaces.
            uniqueNameMeal = insertMeal(st, userAId, "  cHILLI ", false, foodA, foodA);
            ambiguousNameMeal = insertMeal(st, userAId, "Soup", false, foodA);
            deletedRecipeMeal = insertMeal(st, userAId, "Gone", false, foodA);
            unnamedMeal = insertMeal(st, userAId, null, false, foodA);
            deletedMeal = insertMeal(st, userAId, "Chilli", true, foodA);
            otherUserMeal = insertMeal(st, userBId, "Chilli", false, foodB);
            noRecipeUserMeal = insertMeal(st, userCId, "Chilli", false, foodC);

            st.executeUpdate("update meals set updated_at = '" + LONG_AGO + "'");
        }

        Flyway.configure()
                .dataSource(POSTGRES.getJdbcUrl(), POSTGRES.getUsername(), POSTGRES.getPassword())
                .locations("classpath:db/migration")
                .load()
                .migrate();
    }

    @AfterAll
    static void tearDown() throws Exception {
        if (connection != null) connection.close();
        POSTGRES.stop();
    }

    @Test
    void aUniqueLiveNameTagsEveryEntryOfTheMeal() throws Exception {
        assertThat(recipeIdsOf(uniqueNameMeal)).containsExactly(chilliAId, chilliAId);
    }

    @Test
    void theTaggedMealIsBumpedSoTheDeltaFeedDeliversIt() throws Exception {
        assertThat(updatedAt(uniqueNameMeal)).isAfter(LONG_AGO);
        assertThat(updatedAt(otherUserMeal)).isAfter(LONG_AGO);
    }

    @Test
    void theMatchStaysWithinTheUser() throws Exception {
        assertThat(recipeIdsOf(otherUserMeal)).containsExactly(chilliBId);
        assertThat(recipeIdsOf(noRecipeUserMeal)).containsExactly((Long) null);
    }

    @Test
    void anAmbiguousNameIsLeftUntagged() throws Exception {
        assertThat(recipeIdsOf(ambiguousNameMeal)).containsExactly((Long) null);
        assertThat(updatedAt(ambiguousNameMeal)).isEqualTo(LONG_AGO);
    }

    @Test
    void aDeletedRecipeIsNotMatched() throws Exception {
        assertThat(recipeIdsOf(deletedRecipeMeal)).containsExactly((Long) null);
        assertThat(updatedAt(deletedRecipeMeal)).isEqualTo(LONG_AGO);
    }

    @Test
    void unnamedAndDeletedMealsAreUntouched() throws Exception {
        assertThat(recipeIdsOf(unnamedMeal)).containsExactly((Long) null);
        assertThat(recipeIdsOf(deletedMeal)).containsExactly((Long) null);
        assertThat(updatedAt(unnamedMeal)).isEqualTo(LONG_AGO);
        assertThat(updatedAt(deletedMeal)).isEqualTo(LONG_AGO);
        assertThat(updatedAt(noRecipeUserMeal)).isEqualTo(LONG_AGO);
    }

    @Test
    void deletingARecipeLeavesItsEntriesWithoutATag() throws Exception {
        try (Statement st = connection.createStatement()) {
            long user = insertUser(st, "d@example.com");
            long food = insertFood(st, user);
            long recipe = insertRecipe(st, user, "Temp", false);
            long meal = insertMeal(st, user, null, false, food);
            st.executeUpdate("update meal_entries set recipe_id = " + recipe + " where meal_id = " + meal);

            st.executeUpdate("delete from recipes where id = " + recipe);

            assertThat(recipeIdsOf(meal)).containsExactly((Long) null);
        }
    }

    private static java.util.List<Long> recipeIdsOf(long mealId) throws Exception {
        try (Statement st = connection.createStatement();
             ResultSet rs = st.executeQuery("select recipe_id from meal_entries where meal_id = " + mealId + " order by id")) {
            java.util.List<Long> ids = new java.util.ArrayList<>();
            while (rs.next()) {
                long id = rs.getLong(1);
                ids.add(rs.wasNull() ? null : id);
            }
            return ids;
        }
    }

    private static Timestamp updatedAt(long mealId) throws Exception {
        try (Statement st = connection.createStatement();
             ResultSet rs = st.executeQuery("select updated_at from meals where id = " + mealId)) {
            rs.next();
            return rs.getTimestamp(1);
        }
    }

    private static long insertUser(Statement st, String email) throws Exception {
        try (ResultSet rs = st.executeQuery(
                "insert into users (email, password_hash, created_at) values ('" + email + "', 'hash', now()) returning id")) {
            rs.next();
            return rs.getLong(1);
        }
    }

    private static long insertFood(Statement st, long userId) throws Exception {
        try (ResultSet rs = st.executeQuery(
                "insert into foods (user_id, name, calories_per_100g, protein_per_100g) values ("
                        + userId + ", 'Rice " + userId + "', 130, 2.7) returning id")) {
            rs.next();
            return rs.getLong(1);
        }
    }

    private static long insertRecipe(Statement st, long userId, String name, boolean deleted) throws Exception {
        try (ResultSet rs = st.executeQuery(
                "insert into recipes (user_id, name, deleted_at) values (" + userId + ", '" + name + "', "
                        + (deleted ? "now()" : "null") + ") returning id")) {
            rs.next();
            return rs.getLong(1);
        }
    }

    private static long insertMeal(Statement st, long userId, String name, boolean deleted, long... foodIds) throws Exception {
        long mealId;
        try (ResultSet rs = st.executeQuery(
                "insert into meals (user_id, date_time, meal_type, name, deleted_at) values (" + userId
                        + ", now(), 'LUNCH', " + (name == null ? "null" : "'" + name + "'") + ", "
                        + (deleted ? "now()" : "null") + ") returning id")) {
            rs.next();
            mealId = rs.getLong(1);
        }
        for (long foodId : foodIds) {
            st.executeUpdate("insert into meal_entries (meal_id, food_id, quantity_in_grams) values ("
                    + mealId + ", " + foodId + ", 100)");
        }
        return mealId;
    }
}

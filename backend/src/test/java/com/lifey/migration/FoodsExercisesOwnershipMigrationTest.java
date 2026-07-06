package com.lifey.migration;

import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Statement;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * V40__foods_exercises_ownership.sql is the riskiest migration in the codebase
 * (docs/personal_trainer/02-domain-es-migraciok.md, "Változás 1"): it turns the
 * shared foods/exercises catalogs into per-user copies and rewrites every
 * cross-reference (meal_entries, recipe_ingredients, workout_template_exercises,
 * workout_session_exercises, exercise_sets) for every user except the one who
 * keeps the originals. A plain unit test can't catch a wrong join or an
 * off-by-one in the row-by-row copy loop — this runs the real migration
 * against a real Postgres and checks the data on the other side.
 *
 * <p>Sets up two users referencing the pre-V40 shared catalog (migrating only
 * up to V39), then migrates to latest and asserts: the first user keeps the
 * original rows, the second gets an independent copy, and every one of the
 * second user's own child rows now points at their own copy rather than the
 * first user's (or the shared original).
 */
@Testcontainers
class FoodsExercisesOwnershipMigrationTest {

    static final PostgreSQLContainer<?> POSTGRES =
            new PostgreSQLContainer<>("postgres:16").withDatabaseName("lifey").withUsername("lifey").withPassword("lifey");

    static Connection connection;

    static long userAId;
    static long userBId;
    static long sharedFoodId;
    static long sharedExerciseId;
    static long mealBId;
    static long recipeBId;
    static long templateBId;
    static long sessionBId;

    @BeforeAll
    static void migrateToPreV40AndSeedCrossUserData() throws Exception {
        POSTGRES.start();

        Flyway.configure()
                .dataSource(POSTGRES.getJdbcUrl(), POSTGRES.getUsername(), POSTGRES.getPassword())
                .locations("classpath:db/migration")
                .target("39")
                .load()
                .migrate();

        connection = DriverManager.getConnection(POSTGRES.getJdbcUrl(), POSTGRES.getUsername(), POSTGRES.getPassword());
        connection.setAutoCommit(true);

        try (Statement st = connection.createStatement()) {
            // V6__ownership.sql already bootstrapped 'legacy@lifey.local' as the
            // first row in `users` — userA (the real, oldest non-legacy user) and
            // userB come after it, so userA is the one V40 should leave untouched.
            userAId = insertUser(st, "user-a@example.com");
            userBId = insertUser(st, "user-b@example.com");

            // The shared catalog: one food, one exercise (on top of V2's 8 seeded
            // exercises), both still ownerless at this point in the migration history.
            try (ResultSet rs = st.executeQuery(
                    "insert into foods (name, calories_per_100g, protein_per_100g) "
                            + "values ('Rice', 130, 2.7) returning id")) {
                rs.next();
                sharedFoodId = rs.getLong(1);
            }
            try (ResultSet rs = st.executeQuery(
                    "insert into exercises (name) values ('Kettlebell Swing') returning id")) {
                rs.next();
                sharedExerciseId = rs.getLong(1);
            }

            // userA's own rows referencing the shared catalog (nothing should touch these).
            long mealAId = insertMeal(st, userAId);
            insertMealEntry(st, mealAId, sharedFoodId);
            long recipeAId = insertRecipe(st, userAId, "As recipe");
            insertRecipeIngredient(st, recipeAId, sharedFoodId);
            long templateAId = insertTemplate(st, userAId, "As template");
            insertTemplateExercise(st, templateAId, sharedExerciseId);
            long sessionAId = insertSession(st, userAId);
            insertSessionExercise(st, sessionAId, sharedExerciseId);
            insertExerciseSet(st, sessionAId, sharedExerciseId);

            // userB's own rows referencing the *same* shared catalog rows — these are
            // the ones V40 must repoint onto userB's own copy.
            mealBId = insertMeal(st, userBId);
            insertMealEntry(st, mealBId, sharedFoodId);
            recipeBId = insertRecipe(st, userBId, "Bs recipe");
            insertRecipeIngredient(st, recipeBId, sharedFoodId);
            templateBId = insertTemplate(st, userBId, "Bs template");
            insertTemplateExercise(st, templateBId, sharedExerciseId);
            sessionBId = insertSession(st, userBId);
            insertSessionExercise(st, sessionBId, sharedExerciseId);
            insertExerciseSet(st, sessionBId, sharedExerciseId);
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
    void firstNonLegacyUserKeepsTheOriginalCatalogRows() throws Exception {
        assertThat(ownerOf("foods", sharedFoodId)).isEqualTo(userAId);
        assertThat(ownerOf("exercises", sharedExerciseId)).isEqualTo(userAId);
    }

    @Test
    void secondUserGetsIndependentFoodAndExerciseCopies() throws Exception {
        long userBFoodId = onlyFoodIdFor(userBId);
        long userBExerciseId = onlyNonSeedExerciseIdFor(userBId);

        assertThat(userBFoodId).isNotEqualTo(sharedFoodId);
        assertThat(userBExerciseId).isNotEqualTo(sharedExerciseId);
        assertThat(foodName(userBFoodId)).isEqualTo("Rice");
        assertThat(exerciseName(userBExerciseId)).isEqualTo("Kettlebell Swing");
    }

    @Test
    void userBsMealEntryPointsAtUserBsOwnFoodCopy() throws Exception {
        long entryFoodId = singleLong(
                "select food_id from meal_entries where meal_id = ?", mealBId);
        assertThat(ownerOf("foods", entryFoodId)).isEqualTo(userBId);
        assertThat(entryFoodId).isNotEqualTo(sharedFoodId);
    }

    @Test
    void userBsRecipeIngredientPointsAtUserBsOwnFoodCopy() throws Exception {
        long ingredientFoodId = singleLong(
                "select food_id from recipe_ingredients where recipe_id = ?", recipeBId);
        assertThat(ownerOf("foods", ingredientFoodId)).isEqualTo(userBId);
        assertThat(ingredientFoodId).isNotEqualTo(sharedFoodId);
    }

    @Test
    void userBsTemplateExercisePointsAtUserBsOwnExerciseCopy() throws Exception {
        long exerciseId = singleLong(
                "select exercise_id from workout_template_exercises where workout_template_id = ?", templateBId);
        assertThat(ownerOf("exercises", exerciseId)).isEqualTo(userBId);
        assertThat(exerciseId).isNotEqualTo(sharedExerciseId);
    }

    @Test
    void userBsSessionExerciseAndSetPointAtUserBsOwnExerciseCopy() throws Exception {
        long sessionExerciseId = singleLong(
                "select exercise_id from workout_session_exercises where workout_session_id = ?", sessionBId);
        long setExerciseId = singleLong(
                "select exercise_id from exercise_sets where workout_session_id = ?", sessionBId);

        assertThat(ownerOf("exercises", sessionExerciseId)).isEqualTo(userBId);
        assertThat(ownerOf("exercises", setExerciseId)).isEqualTo(userBId);
    }

    @Test
    void userAsOwnRowsAreUntouched() throws Exception {
        // userA's meal/recipe/template/session still reference the original,
        // now-userA-owned catalog rows — nothing should have been rewritten for them.
        long entryFoodId = singleLong(
                "select me.food_id from meal_entries me join meals m on m.id = me.meal_id where m.user_id = ?", userAId);
        assertThat(entryFoodId).isEqualTo(sharedFoodId);
    }

    @Test
    void userIdIsNotNullAndIndexed() throws Exception {
        try (Statement st = connection.createStatement();
             ResultSet rs = st.executeQuery("select count(*) from foods where user_id is null")) {
            rs.next();
            assertThat(rs.getLong(1)).isZero();
        }
        try (Statement st = connection.createStatement();
             ResultSet rs = st.executeQuery("select count(*) from exercises where user_id is null")) {
            rs.next();
            assertThat(rs.getLong(1)).isZero();
        }
    }

    @Test
    void barcodeAndNameUniquenessAreNowPerUserNotGlobal() throws Exception {
        // Two different users can each own a food with the same name/barcode.
        try (PreparedStatement ps = connection.prepareStatement(
                "insert into foods (user_id, name, calories_per_100g, protein_per_100g, barcode) "
                        + "values (?, 'Duplicate Name', 1, 1, 'dup-barcode')")) {
            ps.setLong(1, userAId);
            ps.executeUpdate();
        }
        try (PreparedStatement ps = connection.prepareStatement(
                "insert into foods (user_id, name, calories_per_100g, protein_per_100g, barcode) "
                        + "values (?, 'Duplicate Name', 1, 1, 'dup-barcode')")) {
            ps.setLong(1, userBId);
            ps.executeUpdate();
        }
        // No exception means the unique indexes are (user_id, ...) rather than global.
    }

    private static long insertUser(Statement st, String email) throws Exception {
        try (ResultSet rs = st.executeQuery(
                "insert into users (email, password_hash, created_at) "
                        + "values ('" + email + "', 'hash', now()) returning id")) {
            rs.next();
            return rs.getLong(1);
        }
    }

    private static long insertMeal(Statement st, long userId) throws Exception {
        try (ResultSet rs = st.executeQuery(
                "insert into meals (user_id, date_time, meal_type) "
                        + "values (" + userId + ", now(), 'LUNCH') returning id")) {
            rs.next();
            return rs.getLong(1);
        }
    }

    private static void insertMealEntry(Statement st, long mealId, long foodId) throws Exception {
        st.executeUpdate("insert into meal_entries (meal_id, food_id, quantity_in_grams) "
                + "values (" + mealId + ", " + foodId + ", 100)");
    }

    private static long insertRecipe(Statement st, long userId, String name) throws Exception {
        try (ResultSet rs = st.executeQuery(
                "insert into recipes (user_id, name) values (" + userId + ", '" + name + "') returning id")) {
            rs.next();
            return rs.getLong(1);
        }
    }

    private static void insertRecipeIngredient(Statement st, long recipeId, long foodId) throws Exception {
        st.executeUpdate("insert into recipe_ingredients (recipe_id, food_id, quantity_in_grams) "
                + "values (" + recipeId + ", " + foodId + ", 50)");
    }

    private static long insertTemplate(Statement st, long userId, String name) throws Exception {
        try (ResultSet rs = st.executeQuery(
                "insert into workout_templates (user_id, name) values (" + userId + ", '" + name + "') returning id")) {
            rs.next();
            return rs.getLong(1);
        }
    }

    private static void insertTemplateExercise(Statement st, long templateId, long exerciseId) throws Exception {
        st.executeUpdate("insert into workout_template_exercises (workout_template_id, exercise_id) "
                + "values (" + templateId + ", " + exerciseId + ")");
    }

    private static long insertSession(Statement st, long userId) throws Exception {
        try (ResultSet rs = st.executeQuery(
                "insert into workout_sessions (user_id, started_at) values (" + userId + ", now()) returning id")) {
            rs.next();
            return rs.getLong(1);
        }
    }

    private static void insertSessionExercise(Statement st, long sessionId, long exerciseId) throws Exception {
        st.executeUpdate("insert into workout_session_exercises (workout_session_id, exercise_id) "
                + "values (" + sessionId + ", " + exerciseId + ")");
    }

    private static void insertExerciseSet(Statement st, long sessionId, long exerciseId) throws Exception {
        st.executeUpdate("insert into exercise_sets (workout_session_id, exercise_id, reps, weight, performed_at) "
                + "values (" + sessionId + ", " + exerciseId + ", 10, 20, now())");
    }

    private long ownerOf(String table, long id) throws Exception {
        return singleLong("select user_id from " + table + " where id = ?", id);
    }

    private long onlyFoodIdFor(long userId) throws Exception {
        return singleLong("select id from foods where user_id = ?", userId);
    }

    private long onlyNonSeedExerciseIdFor(long userId) throws Exception {
        return singleLong("select id from exercises where user_id = ? and name = 'Kettlebell Swing'", userId);
    }

    private String foodName(long id) throws Exception {
        try (PreparedStatement ps = connection.prepareStatement("select name from foods where id = ?")) {
            ps.setLong(1, id);
            try (ResultSet rs = ps.executeQuery()) {
                rs.next();
                return rs.getString(1);
            }
        }
    }

    private String exerciseName(long id) throws Exception {
        try (PreparedStatement ps = connection.prepareStatement("select name from exercises where id = ?")) {
            ps.setLong(1, id);
            try (ResultSet rs = ps.executeQuery()) {
                rs.next();
                return rs.getString(1);
            }
        }
    }

    private long singleLong(String sql, long param) throws Exception {
        try (PreparedStatement ps = connection.prepareStatement(sql)) {
            ps.setLong(1, param);
            try (ResultSet rs = ps.executeQuery()) {
                rs.next();
                return rs.getLong(1);
            }
        }
    }
}

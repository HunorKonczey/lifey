package com.lifey.nutrition.food.backfill;

import com.lifey.common.job.OneTimeJob;
import com.lifey.common.job.OneTimeJobRepository;
import com.lifey.nutrition.food.Food;
import com.lifey.nutrition.food.FoodRepository;
import com.lifey.nutrition.food.backfill.FoodFiberSugarBackfillService.Outcome;
import com.lifey.nutrition.openfoodfacts.OffProduct;
import com.lifey.nutrition.openfoodfacts.client.OpenFoodFactsClient;
import com.lifey.nutrition.openfoodfacts.exception.OffRateLimitedException;
import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.ApplicationContext;
import org.springframework.data.domain.PageRequest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import java.time.Instant;
import java.util.HashSet;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.reset;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * The one-time fibre/sugar backfill (LIF-149) against a real database: the V90 row that starts it, the query that picks the
 * foods, the lease, and a whole run with OpenFoodFacts stubbed - including that a figure somebody set is never overwritten,
 * that the phones' delta sync is told (updatedAt moves), and that a second run does nothing.
 */
@SpringBootTest
@Testcontainers
class FoodFiberSugarBackfillRegressionTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    @Autowired
    FoodFiberSugarBackfillService service;
    @Autowired
    OneTimeJobRepository jobs;
    @Autowired
    FoodRepository foods;
    @Autowired
    UserRepository users;
    @Autowired
    JdbcTemplate jdbc;
    @Autowired
    ApplicationContext context;

    @MockitoBean
    OpenFoodFactsClient off;

    private User owner;

    @BeforeEach
    void seed() {
        reset(off);
        // Every test starts from the state a fresh deploy finds: the V90 row, untouched.
        jdbc.update("update one_time_jobs set cursor_id = 0, claimed_until = null, completed_at = null, processed_count = 0, filled_count = 0"
                + " where name = ?", FoodFiberSugarBackfillService.JOB_NAME);
        jdbc.update("update foods set deleted_at = now()");
        owner = new User();
        owner.setEmail("backfill-" + System.nanoTime() + "@example.com");
        owner.setPasswordHash("irrelevant");
        owner.setCreatedAt(Instant.now());
        owner.setRoles(new HashSet<>(List.of(Role.ROLE_USER)));
        owner = users.save(owner);
    }

    private Food food(String name, String barcode, Double fiber, Double sugar) {
        Food f = new Food();
        f.setUser(owner);
        f.setName(name + " " + System.nanoTime());
        f.setCaloriesPer100g(100);
        f.setProteinPer100g(5);
        f.setBarcode(barcode);
        f.setFiberPer100g(fiber);
        f.setSugarPer100g(sugar);
        return foods.save(f);
    }

    private static OffProduct product(Double fiber, Double sugar) {
        return new OffProduct("X", null, 100.0, 5.0, 10.0, 2.0, fiber, sugar);
    }

    @Test
    void theFirstDeploy_findsTheJobPending_atTheStart() {
        OneTimeJob job = jobs.findById(FoodFiberSugarBackfillService.JOB_NAME).orElseThrow();

        assertThat(job.isCompleted()).isFalse();
        assertThat(job.getCursorId()).isZero();
        assertThat(job.getClaimedUntil()).isNull();
    }

    @Test
    void theJobBeanIsNotCreatedWhereTheBackfillIsNotEnabled() {
        assertThat(context.getBeanNamesForType(FoodFiberSugarBackfillJob.class)).isEmpty();
    }

    @Test
    void theBatchPicksLiveFoodsWithABarcodeThatLackEitherFigure_inIdOrder_afterTheCursor() {
        Food neither = food("neither", "111", null, null);
        Food onlySugarMissing = food("fibre only", "222", 3.0, null);
        Food onlyFiberMissing = food("sugar only", "333", null, 1.0);
        food("complete", "444", 3.0, 1.0);
        food("no barcode", null, null, null);
        food("blank barcode", "", null, null);
        Food deleted = food("deleted", "555", null, null);
        deleted.setDeletedAt(Instant.now());
        foods.save(deleted);

        List<Food> all = foods.findBackfillBatch(0, PageRequest.of(0, 50));
        List<Food> afterFirst = foods.findBackfillBatch(neither.getId(), PageRequest.of(0, 50));
        List<Food> firstOnly = foods.findBackfillBatch(0, PageRequest.of(0, 1));

        assertThat(all).extracting(Food::getId).containsExactly(neither.getId(), onlySugarMissing.getId(), onlyFiberMissing.getId());
        assertThat(afterFirst).extracting(Food::getId).containsExactly(onlySugarMissing.getId(), onlyFiberMissing.getId());
        assertThat(firstOnly).extracting(Food::getId).containsExactly(neither.getId());
    }

    @Test
    void theLeaseLetsOneRunnerIn_untilItExpires_andACompletedJobNeverAgain() {
        String name = FoodFiberSugarBackfillService.JOB_NAME;
        Instant now = Instant.parse("2026-10-09T12:00:00Z");

        assertThat(jobs.claim(name, now, now.plusSeconds(600))).isEqualTo(1);
        assertThat(jobs.claim(name, now.plusSeconds(60), now.plusSeconds(660))).isZero();
        assertThat(jobs.claim(name, now.plusSeconds(601), now.plusSeconds(1200))).isEqualTo(1);

        jobs.saveProgress(name, 42, 5, 3, null);
        OneTimeJob afterProgress = jobs.findById(name).orElseThrow();
        assertThat(afterProgress.getCursorId()).isEqualTo(42);
        assertThat(afterProgress.getProcessedCount()).isEqualTo(5);
        assertThat(afterProgress.getFilledCount()).isEqualTo(3);
        assertThat(afterProgress.getClaimedUntil()).isNull();

        assertThat(jobs.complete(name, now)).isEqualTo(1);
        assertThat(jobs.claim(name, now.plusSeconds(100_000), now.plusSeconds(200_000))).isZero();
        assertThat(jobs.complete(name, now)).isZero();
    }

    @Test
    void aWholeRun_fillsOnlyWhatIsMissing_neverOverwrites_bumpsUpdatedAt_andASecondRunDoesNothing() {
        Food neither = food("neither", "111", null, null);
        Food keepsFiber = food("keeps fibre", "222", 9.0, null);
        Food noData = food("no data", "333", null, null);
        Food complete = food("complete", "444", 3.0, 1.0);
        Instant before = foods.findById(neither.getId()).orElseThrow().getUpdatedAt();
        when(off.findByBarcode("111")).thenReturn(Optional.of(product(8.5, 14.0)));
        when(off.findByBarcode("222")).thenReturn(Optional.of(product(1.0, 2.5)));
        when(off.findByBarcode("333")).thenReturn(Optional.empty());

        assertThat(service.runOnce()).isEqualTo(Outcome.COMPLETED);

        Food a = foods.findById(neither.getId()).orElseThrow();
        assertThat(a.getFiberPer100g()).isEqualTo(8.5);
        assertThat(a.getSugarPer100g()).isEqualTo(14.0);
        assertThat(a.getUpdatedAt()).isAfter(before);
        // A figure that is there stays; the missing one is filled from OFF.
        Food b = foods.findById(keepsFiber.getId()).orElseThrow();
        assertThat(b.getFiberPer100g()).isEqualTo(9.0);
        assertThat(b.getSugarPer100g()).isEqualTo(2.5);
        Food c = foods.findById(noData.getId()).orElseThrow();
        assertThat(c.getFiberPer100g()).isNull();
        assertThat(c.getSugarPer100g()).isNull();
        verify(off, never()).findByBarcode("444");
        assertThat(foods.findById(complete.getId()).orElseThrow().getFiberPer100g()).isEqualTo(3.0);

        OneTimeJob job = jobs.findById(FoodFiberSugarBackfillService.JOB_NAME).orElseThrow();
        assertThat(job.isCompleted()).isTrue();
        assertThat(job.getClaimedUntil()).isNull();
        assertThat(job.getFilledCount()).isEqualTo(2);

        reset(off);
        assertThat(service.runOnce()).isEqualTo(Outcome.NOT_RUN);
        verify(off, never()).findByBarcode(any());
    }

    @Test
    void aRateLimitedRun_resumesAtTheFoodItStoppedOn_andFinishesTheJobLater() {
        Food first = food("first", "111", null, null);
        Food second = food("second", "222", null, null);
        when(off.findByBarcode("111")).thenReturn(Optional.of(product(1.0, 2.0)));
        when(off.findByBarcode("222")).thenThrow(new OffRateLimitedException("429"));

        assertThat(service.runOnce()).isEqualTo(Outcome.INTERRUPTED);

        OneTimeJob stopped = jobs.findById(FoodFiberSugarBackfillService.JOB_NAME).orElseThrow();
        assertThat(stopped.isCompleted()).isFalse();
        assertThat(stopped.getCursorId()).isEqualTo(first.getId());
        assertThat(stopped.getClaimedUntil()).isNull();
        assertThat(foods.findById(first.getId()).orElseThrow().getFiberPer100g()).isEqualTo(1.0);

        reset(off);
        when(off.findByBarcode("222")).thenReturn(Optional.of(product(4.0, 5.0)));

        assertThat(service.runOnce()).isEqualTo(Outcome.COMPLETED);

        verify(off, never()).findByBarcode("111");
        assertThat(foods.findById(second.getId()).orElseThrow().getFiberPer100g()).isEqualTo(4.0);
        assertThat(jobs.findById(FoodFiberSugarBackfillService.JOB_NAME).orElseThrow().isCompleted()).isTrue();
    }
}

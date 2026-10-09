package com.lifey.nutrition.food.backfill;

import com.lifey.common.job.OneTimeJob;
import com.lifey.common.job.OneTimeJobRepository;
import com.lifey.nutrition.food.Food;
import com.lifey.nutrition.food.FoodRepository;
import com.lifey.nutrition.food.backfill.FoodFiberSugarBackfillService.Outcome;
import com.lifey.nutrition.openfoodfacts.OffProduct;
import com.lifey.nutrition.openfoodfacts.client.OpenFoodFactsClient;
import com.lifey.nutrition.openfoodfacts.exception.OffRateLimitedException;
import com.lifey.nutrition.openfoodfacts.exception.OffUnavailableException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** The backfill's decisions, with OpenFoodFacts and the database stubbed: what it fills, when it stops, where it resumes. */
@ExtendWith(MockitoExtension.class)
class FoodFiberSugarBackfillServiceTest {

    private static final String JOB = FoodFiberSugarBackfillService.JOB_NAME;
    private static final Instant NOW = Instant.parse("2026-10-09T12:00:00Z");

    @Mock
    OneTimeJobRepository jobs;
    @Mock
    FoodRepository foods;
    @Mock
    FoodBackfillWriter writer;
    @Mock
    OpenFoodFactsClient off;

    private FoodFiberSugarBackfillService service;

    @BeforeEach
    void setUp() {
        FoodFiberSugarBackfillProperties properties = new FoodFiberSugarBackfillProperties(
                true, 2, Duration.ZERO, 2, 3, Duration.ofMinutes(10), Duration.ofMinutes(1), Duration.ofMinutes(15));
        service = new FoodFiberSugarBackfillService(jobs, foods, writer, off, properties, Clock.fixed(NOW, ZoneOffset.UTC));
    }

    private OneTimeJob job(long cursor, boolean completed) {
        OneTimeJob job = new OneTimeJob();
        job.setName(JOB);
        job.setCursorId(cursor);
        job.setCompletedAt(completed ? NOW : null);
        return job;
    }

    private void claimable(long cursor) {
        when(jobs.findById(JOB)).thenReturn(Optional.of(job(cursor, false)));
        when(jobs.claim(eq(JOB), eq(NOW), any())).thenReturn(1);
    }

    private static Food food(long id, String barcode) {
        Food food = new Food();
        food.setId(id);
        food.setBarcode(barcode);
        return food;
    }

    private static OffProduct product(Double fiber, Double sugar) {
        return new OffProduct("X", null, 100.0, 5.0, 10.0, 2.0, fiber, sugar);
    }

    @Test
    void aCompletedJob_isLeftAlone() {
        when(jobs.findById(JOB)).thenReturn(Optional.of(job(0, true)));

        assertThat(service.runOnce()).isEqualTo(Outcome.NOT_RUN);

        verify(jobs, never()).claim(any(), any(), any());
        verify(off, never()).findByBarcode(any());
    }

    @Test
    void aJobThatDoesNotExist_isLeftAlone() {
        when(jobs.findById(JOB)).thenReturn(Optional.empty());

        assertThat(service.runOnce()).isEqualTo(Outcome.NOT_RUN);
    }

    @Test
    void aJobHeldByAnotherRun_isLeftAlone() {
        when(jobs.findById(JOB)).thenReturn(Optional.of(job(0, false)));
        when(jobs.claim(eq(JOB), eq(NOW), any())).thenReturn(0);

        assertThat(service.runOnce()).isEqualTo(Outcome.NOT_RUN);

        verify(foods, never()).findBackfillBatch(anyLong(), any());
        verify(off, never()).findByBarcode(any());
    }

    @Test
    void itFillsWhatOpenFoodFactsHas_leavesWhatItLacks_andCompletes() {
        claimable(0);
        when(foods.findBackfillBatch(eq(0L), any())).thenReturn(List.of(food(1, " 5997 "), food(2, "5998")));
        when(foods.findBackfillBatch(eq(2L), any())).thenReturn(List.of());
        when(off.findByBarcode("5997")).thenReturn(Optional.of(product(8.5, 14.0)));
        when(off.findByBarcode("5998")).thenReturn(Optional.empty());
        when(writer.fill(1, 8.5, 14.0)).thenReturn(2);

        assertThat(service.runOnce()).isEqualTo(Outcome.COMPLETED);

        verify(writer).fill(1, 8.5, 14.0);
        verify(writer, never()).fill(eq(2L), any(), any());
        verify(jobs).saveProgress(eq(JOB), eq(2L), eq(2), eq(1), any());
        verify(jobs).complete(JOB, NOW);
    }

    @Test
    void theSameBarcodeInSeveralFoods_isAskedForOnce_andFillsEachOfThem() {
        claimable(0);
        when(foods.findBackfillBatch(eq(0L), any())).thenReturn(List.of(food(1, "5997"), food(2, " 5997")));
        when(foods.findBackfillBatch(eq(2L), any())).thenReturn(List.of());
        when(off.findByBarcode("5997")).thenReturn(Optional.of(product(8.5, 14.0)));
        when(writer.fill(1, 8.5, 14.0)).thenReturn(2);
        when(writer.fill(2, 8.5, 14.0)).thenReturn(2);

        assertThat(service.runOnce()).isEqualTo(Outcome.COMPLETED);

        verify(off, times(1)).findByBarcode("5997");
        verify(writer).fill(1, 8.5, 14.0);
        verify(writer).fill(2, 8.5, 14.0);
    }

    @Test
    void aProductWithNeitherFigure_writesNothing() {
        claimable(0);
        when(foods.findBackfillBatch(eq(0L), any())).thenReturn(List.of(food(1, "5997")));
        when(foods.findBackfillBatch(eq(1L), any())).thenReturn(List.of());
        when(off.findByBarcode("5997")).thenReturn(Optional.of(product(null, null)));

        assertThat(service.runOnce()).isEqualTo(Outcome.COMPLETED);

        verify(writer, never()).fill(anyLong(), any(), any());
    }

    @Test
    void anImplausibleFigureIsNotWritten_theOtherOneIs() {
        claimable(0);
        when(foods.findBackfillBatch(eq(0L), any())).thenReturn(List.of(food(1, "5997"), food(2, "5998")));
        when(foods.findBackfillBatch(eq(2L), any())).thenReturn(List.of());
        when(off.findByBarcode("5997")).thenReturn(Optional.of(product(400.0, 3.0)));
        when(off.findByBarcode("5998")).thenReturn(Optional.of(product(-1.0, 120.0)));
        when(writer.fill(1, null, 3.0)).thenReturn(1);

        assertThat(service.runOnce()).isEqualTo(Outcome.COMPLETED);

        verify(writer).fill(1, null, 3.0);
        verify(writer, never()).fill(eq(2L), any(), any());
    }

    @Test
    void itContinuesFromTheSavedCursor() {
        claimable(40);
        when(foods.findBackfillBatch(eq(40L), any())).thenReturn(List.of());

        assertThat(service.runOnce()).isEqualTo(Outcome.COMPLETED);

        verify(off, never()).findByBarcode(any());
        verify(jobs).complete(JOB, NOW);
    }

    @Test
    void aRateLimit_stopsTheRun_keepsTheCursorOnTheLastFinishedFood_andDoesNotComplete() {
        claimable(0);
        when(foods.findBackfillBatch(eq(0L), any())).thenReturn(List.of(food(1, "5997"), food(2, "5998")));
        when(off.findByBarcode("5997")).thenReturn(Optional.of(product(1.0, 2.0)));
        when(off.findByBarcode("5998")).thenThrow(new OffRateLimitedException("429"));
        when(writer.fill(1, 1.0, 2.0)).thenReturn(2);

        assertThat(service.runOnce()).isEqualTo(Outcome.INTERRUPTED);

        // Food 1 is done; food 2 was not looked up, so the run resumes at it. The lease is released (null).
        verify(jobs).saveProgress(eq(JOB), eq(1L), eq(1), eq(1), isNull());
        verify(jobs, never()).complete(any(), any());
    }

    @Test
    void aFoodThatFailsOnceIsRetried() {
        claimable(0);
        when(foods.findBackfillBatch(eq(0L), any())).thenReturn(List.of(food(1, "5997")));
        when(foods.findBackfillBatch(eq(1L), any())).thenReturn(List.of());
        when(off.findByBarcode("5997"))
                .thenThrow(new OffUnavailableException("timeout"))
                .thenReturn(Optional.of(product(2.0, 1.0)));
        when(writer.fill(1, 2.0, 1.0)).thenReturn(2);

        assertThat(service.runOnce()).isEqualTo(Outcome.COMPLETED);

        verify(writer).fill(1, 2.0, 1.0);
    }

    @Test
    void aFoodThatNeverAnswers_isSkipped_andTheRunGoesOn() {
        claimable(0);
        when(foods.findBackfillBatch(eq(0L), any())).thenReturn(List.of(food(1, "5997"), food(2, "5998")));
        when(foods.findBackfillBatch(eq(2L), any())).thenReturn(List.of());
        when(off.findByBarcode("5997")).thenThrow(new OffUnavailableException("timeout"));
        when(off.findByBarcode("5998")).thenReturn(Optional.of(product(2.0, 1.0)));
        when(writer.fill(2, 2.0, 1.0)).thenReturn(2);

        assertThat(service.runOnce()).isEqualTo(Outcome.COMPLETED);

        // Two attempts at food 1 (attempts = 2), then food 2 as usual; the cursor moves past the skipped one with it.
        verify(off, times(2)).findByBarcode("5997");
        verify(writer).fill(2, 2.0, 1.0);
        verify(jobs).saveProgress(eq(JOB), eq(2L), eq(2), eq(1), any());
        verify(jobs).complete(JOB, NOW);
    }

    @Test
    void whenOpenFoodFactsIsDown_theRunStopsAfterAFewFoods_andTheCursorStaysBeforeThem() {
        claimable(7);
        when(foods.findBackfillBatch(eq(7L), any())).thenReturn(List.of(food(8, "1"), food(9, "2")));
        when(foods.findBackfillBatch(eq(9L), any())).thenReturn(List.of(food(10, "3"), food(11, "4")));
        when(off.findByBarcode(any())).thenThrow(new OffUnavailableException("down"));

        assertThat(service.runOnce()).isEqualTo(Outcome.INTERRUPTED);

        // maxConsecutiveFailures = 3: foods 8, 9, 10 failed; 11 was never tried. Nothing was finished, so the cursor stays at 7.
        verify(off, never()).findByBarcode("4");
        verify(jobs).saveProgress(eq(JOB), eq(7L), eq(0), eq(0), isNull());
        verify(jobs, never()).complete(any(), any());
        verify(writer, never()).fill(anyLong(), any(), any());
        verify(jobs, never()).saveProgress(eq(JOB), eq(10L), anyInt(), anyInt(), any());
    }
}

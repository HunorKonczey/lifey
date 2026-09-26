package com.lifey.trainer;

import com.lifey.trainer.PersonalRecordCounter.SetFact;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;

class PersonalRecordCounterTest {

    private static final Instant NOW = Instant.parse("2026-09-25T12:00:00Z");
    private static final Instant WEEK_AGO = NOW.minusSeconds(7 * 24 * 3600);
    private static final long BENCH = 1L;
    private static final long SQUAT = 2L;

    private static Instant daysAgo(int days) {
        return NOW.minusSeconds(days * 24L * 3600);
    }

    private static SetFact set(long session, int startedDaysAgo, long exercise, double weight, int reps, int minute) {
        Instant started = daysAgo(startedDaysAgo);
        return new SetFact(session, started, exercise, weight, reps, started.plusSeconds(minute * 60L));
    }

    @Test
    void aFirstEverSetIsNotARecord() {
        assertEquals(0, PersonalRecordCounter.countSince(List.of(set(1, 2, BENCH, 50, 8, 1)), WEEK_AGO));
    }

    @Test
    void aHeavierSetAgainstEarlierHistoryIsOneOrMoreRecords() {
        List<SetFact> sets = new ArrayList<>();
        sets.add(set(1, 20, BENCH, 40, 8, 1));   // baseline, out of the window
        sets.add(set(2, 3, BENCH, 50, 8, 1));    // heavier: max weight + estimated 1RM
        // Two records, at the same weight the reps did not beat anything.
        assertEquals(2, PersonalRecordCounter.countSince(sets, WEEK_AGO));
    }

    @Test
    void matchingTheBestIsNotARecord() {
        List<SetFact> sets = List.of(set(1, 20, BENCH, 50, 8, 1), set(2, 3, BENCH, 50, 8, 1));
        assertEquals(0, PersonalRecordCounter.countSince(sets, WEEK_AGO));
    }

    @Test
    void moreRepsAtTheSameWeightIsARepsRecordAndOftenAnEstimatedOneRmToo() {
        List<SetFact> sets = List.of(set(1, 20, BENCH, 50, 8, 1), set(2, 3, BENCH, 50, 10, 1));
        // reps at 50 kg (8 -> 10) and estimated 1RM (63.3 -> 66.7); the weight itself did not move.
        assertEquals(2, PersonalRecordCounter.countSince(sets, WEEK_AGO));
    }

    @Test
    void threeSetsInARowThatEachBeatTheLastAreStillOneHeaviestSet() {
        List<SetFact> sets = new ArrayList<>();
        sets.add(set(1, 20, BENCH, 40, 5, 1));
        sets.add(set(2, 3, BENCH, 45, 5, 1));
        sets.add(set(2, 3, BENCH, 50, 5, 2));
        sets.add(set(2, 3, BENCH, 55, 5, 3));
        // max weight once + estimated 1RM once, not three of each.
        assertEquals(2, PersonalRecordCounter.countSince(sets, WEEK_AGO));
    }

    @Test
    void eachExerciseCountsOnItsOwn() {
        List<SetFact> sets = new ArrayList<>();
        sets.add(set(1, 20, BENCH, 40, 5, 1));
        sets.add(set(1, 20, SQUAT, 60, 5, 2));
        sets.add(set(2, 3, BENCH, 50, 5, 1));
        sets.add(set(2, 3, SQUAT, 60, 5, 2)); // equal: nothing
        assertEquals(2, PersonalRecordCounter.countSince(sets, WEEK_AGO));
    }

    @Test
    void recordsBeforeTheWindowRaiseTheBarButAreNotCounted() {
        List<SetFact> sets = new ArrayList<>();
        sets.add(set(1, 30, BENCH, 40, 5, 1));
        sets.add(set(2, 20, BENCH, 60, 5, 1));   // a record, three weeks ago
        sets.add(set(3, 2, BENCH, 55, 5, 1));    // lighter than the 60: nothing this week
        assertEquals(0, PersonalRecordCounter.countSince(sets, WEEK_AGO));
    }

    @Test
    void aBodyweightHistoryHasNoWeightBaselineToBeat() {
        List<SetFact> sets = List.of(set(1, 20, BENCH, 0, 10, 1), set(2, 3, BENCH, 0, 12, 1));
        // Only "more reps at 0 kg" fires; there is no max-weight / 1RM baseline.
        assertEquals(1, PersonalRecordCounter.countSince(sets, WEEK_AGO));
    }

    @Test
    void noSetsMeansNoRecords() {
        assertEquals(0, PersonalRecordCounter.countSince(List.of(), WEEK_AGO));
    }
}

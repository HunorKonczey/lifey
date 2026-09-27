package com.lifey.trainer;

import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;

/**
 * Counts the strength personal records a client set inside a window — the
 * "🏆 2 PRs this week" chip of the trainer's client list.
 *
 * <p>A record is never stored; like on the phone (docs/38-personal-records-plan.md,
 * {@code personal_record.dart}) it is derived by replaying the history from
 * the oldest set: a set breaks a record when it is strictly better than
 * everything that came before it, for one of three kinds — heaviest weight,
 * best estimated 1RM (Epley: {@code weight × (1 + reps / 30)}) or most reps at
 * the same weight. A kind never fires without an earlier value to beat, so a
 * first-ever set is not a record. Sets of one exercise within a session are
 * judged against the running best, and a session counts each kind once per
 * exercise — three heavy sets in a row that each beat the last are still one
 * "heaviest set" — which is what the Sessions list on the phone shows.
 * Cardio sessions are not counted.
 */
public final class PersonalRecordCounter {

    private PersonalRecordCounter() {
    }

    /** One logged set, with the session it belongs to. */
    public record SetFact(
            Long sessionId, Instant sessionStartedAt, Long exerciseId, double weight, int reps, Instant performedAt) {
    }

    private enum Kind { MAX_WEIGHT, ESTIMATED_ONE_RM, REPS_AT_WEIGHT }

    private static final class Baseline {
        Double maxWeight;
        Double bestOneRm;
        final Map<Double, Integer> maxRepsByWeight = new HashMap<>();

        Set<Kind> detect(double weight, int reps) {
            Set<Kind> kinds = new TreeSet<>();
            if (weight > 0) {
                if (maxWeight != null && weight > maxWeight) {
                    kinds.add(Kind.MAX_WEIGHT);
                }
                if (bestOneRm != null && estimatedOneRm(weight, reps) > bestOneRm) {
                    kinds.add(Kind.ESTIMATED_ONE_RM);
                }
            }
            Integer priorReps = maxRepsByWeight.get(weight);
            if (priorReps != null && reps > priorReps) {
                kinds.add(Kind.REPS_AT_WEIGHT);
            }
            return kinds;
        }

        void extend(double weight, int reps) {
            if (weight > 0) {
                if (maxWeight == null || weight > maxWeight) {
                    maxWeight = weight;
                }
                double orm = estimatedOneRm(weight, reps);
                if (bestOneRm == null || orm > bestOneRm) {
                    bestOneRm = orm;
                }
            }
            maxRepsByWeight.merge(weight, reps, Math::max);
        }
    }

    static double estimatedOneRm(double weight, int reps) {
        return weight * (1 + reps / 30.0);
    }

    /**
     * @param sets every finished strength set of the client, oldest session first and each session's sets in
     *             {@code performedAt} order
     * @param since only sessions that started at or after this instant are counted
     */
    public static int countSince(List<SetFact> sets, Instant since) {
        Map<Long, Baseline> baselines = new HashMap<>();
        int count = 0;

        // Consecutive facts of one session and one exercise form a run; the sets arrive grouped by session.
        int i = 0;
        while (i < sets.size()) {
            Long sessionId = sets.get(i).sessionId();
            int end = i;
            while (end < sets.size() && sets.get(end).sessionId().equals(sessionId)) {
                end++;
            }
            Map<Long, Set<Kind>> perExercise = new HashMap<>();
            for (int j = i; j < end; j++) {
                SetFact set = sets.get(j);
                Baseline baseline = baselines.computeIfAbsent(set.exerciseId(), id -> new Baseline());
                perExercise.computeIfAbsent(set.exerciseId(), id -> new TreeSet<>())
                        .addAll(baseline.detect(set.weight(), set.reps()));
                baseline.extend(set.weight(), set.reps());
            }
            if (!sets.get(i).sessionStartedAt().isBefore(since)) {
                for (Set<Kind> kinds : perExercise.values()) {
                    count += kinds.size();
                }
            }
            i = end;
        }
        return count;
    }
}

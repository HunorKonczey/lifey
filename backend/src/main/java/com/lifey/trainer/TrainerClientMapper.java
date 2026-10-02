package com.lifey.trainer;

import com.lifey.trainer.entity.TrainerClient;
import com.lifey.trainer.dto.MyTrainerResponse;
import com.lifey.trainer.dto.PendingInviteResponse;
import com.lifey.trainer.dto.TrainerClientResponse;
import com.lifey.trainer.dto.TrainerInviteResponse;
import com.lifey.trainer.dto.WeightTrendPoint;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

/**
 * Maps {@link TrainerClient} rows to the different DTOs each side of the
 * relationship sees — the same row means "an invite I sent" to the trainer
 * and "an invite I received" to the client, so the mapping is per-viewpoint
 * rather than a single generic response.
 */
public final class TrainerClientMapper {

    private TrainerClientMapper() {
    }

    public static TrainerInviteResponse toInviteResponse(TrainerClient tc) {
        return new TrainerInviteResponse(tc.getId(), tc.getClient().getEmail(), tc.getCreatedAt(), tc.getExpiresAt());
    }

    public static PendingInviteResponse toPendingInviteResponse(TrainerClient tc) {
        return new PendingInviteResponse(tc.getId(), tc.getTrainer().getEmail(), tc.getCreatedAt(), tc.getExpiresAt());
    }

    /** The computed half of a client card — everything that is not read straight off the relationship. */
    public record ClientCardStats(
            List<WeightTrendPoint> weightTrend, int assignedPlanCount, int workoutsPerWeek,
            Instant lastActivityAt, LocalDate lastWeightAt, int missedWorkoutCount,
            Integer avgCalories7d, Integer prCount7d, Integer dailyCalorieGoal) {
    }

    public static TrainerClientResponse toClientResponse(TrainerClient tc, ClientCardStats stats) {
        return new TrainerClientResponse(
                tc.getClient().getId(),
                tc.getClient().getEmail(),
                tc.getClient().getFirstName(),
                tc.getClient().getLastName(),
                tc.getRespondedAt(),
                stats.weightTrend(),
                stats.assignedPlanCount(),
                stats.workoutsPerWeek(),
                stats.lastActivityAt(),
                stats.lastWeightAt(),
                stats.missedWorkoutCount(),
                stats.avgCalories7d(),
                stats.prCount7d(),
                stats.dailyCalorieGoal());
    }

    public static MyTrainerResponse toMyTrainerResponse(TrainerClient tc) {
        return new MyTrainerResponse(
                tc.getTrainer().getId(),
                tc.getTrainer().getEmail(),
                tc.getTrainer().getFirstName(),
                tc.getTrainer().getLastName(),
                tc.getRespondedAt());
    }
}

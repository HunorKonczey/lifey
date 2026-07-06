package com.lifey.trainer;

import com.lifey.trainer.dto.MyTrainerResponse;
import com.lifey.trainer.dto.PendingInviteResponse;
import com.lifey.trainer.dto.TrainerClientResponse;
import com.lifey.trainer.dto.TrainerInviteResponse;
import com.lifey.trainer.dto.WeightTrendPoint;

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

    public static TrainerClientResponse toClientResponse(
            TrainerClient tc, List<WeightTrendPoint> weightTrend, int assignedPlanCount, int workoutsPerWeek) {
        return new TrainerClientResponse(
                tc.getClient().getId(),
                tc.getClient().getEmail(),
                tc.getRespondedAt(),
                weightTrend,
                assignedPlanCount,
                workoutsPerWeek);
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

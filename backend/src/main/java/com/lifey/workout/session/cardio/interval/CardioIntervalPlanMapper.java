package com.lifey.workout.session.cardio.interval;

import com.lifey.workout.session.cardio.interval.dto.CardioIntervalPlanResponse;
import com.lifey.workout.session.cardio.interval.dto.IntervalStepEntry;

import java.util.ArrayList;
import java.util.List;

/**
 * Maps {@link CardioIntervalPlan} entities to plan DTOs, rebuilding the
 * editor's tree from the flat step rows. Request-side mapping lives in the
 * service, which validates the shape first.
 */
public final class CardioIntervalPlanMapper {

    private CardioIntervalPlanMapper() {
    }

    public static CardioIntervalPlanResponse toResponse(CardioIntervalPlan plan) {
        return new CardioIntervalPlanResponse(
                plan.getId(),
                plan.getName(),
                toStepEntries(plan.getSteps()),
                plan.getUpdatedAt(),
                plan.getDeletedAt()
        );
    }

    /**
     * Flat rows in, one level of nesting out. A block's children are read off
     * the entity's own {@code children} view rather than re-derived by
     * grouping on parent ids — on the create path the rows have no ids yet,
     * so id-keyed grouping would silently hand every top-level step the same
     * children. Both levels arrive ordered by {@code stepIndex}, which is
     * per-sibling, so nothing needs re-sorting.
     */
    private static List<IntervalStepEntry> toStepEntries(List<CardioIntervalStep> steps) {
        List<IntervalStepEntry> topLevel = new ArrayList<>();
        for (CardioIntervalStep step : steps) {
            if (step.getParent() != null) continue;
            List<IntervalStepEntry> children = step.getStepType() == IntervalStepType.REPEAT
                    ? step.getChildren().stream().map(child -> toEntry(child, null)).toList()
                    : null;
            topLevel.add(toEntry(step, children));
        }
        return topLevel;
    }

    private static IntervalStepEntry toEntry(CardioIntervalStep step, List<IntervalStepEntry> children) {
        return new IntervalStepEntry(
                step.getStepType(),
                step.getName(),
                step.getIntensity(),
                step.getDurationSeconds(),
                step.getRepeatCount(),
                children
        );
    }
}

package com.lifey.workout.exercise;

import com.lifey.common.domain.SyncableEntity;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

/**
 * Soft-deleted via {@code deletedAt} (inherited from {@link
 * com.lifey.common.domain.SyncableEntity}) rather than a hard delete — this
 * also fixes a pre-existing gap (docs/16-delta-sync-rollout.md §1): deleting
 * an exercise still referenced by workout_template_exercises/
 * workout_session_exercises used to throw a DB constraint violation; soft
 * delete leaves the row in place so those FKs still resolve.
 */
@Getter
@Setter
@Entity
@Table(name = "exercises")
public class Exercise extends SyncableEntity {

    @Column(nullable = false)
    private String name;

    @Enumerated(EnumType.STRING)
    @Column(length = 32)
    private MuscleGroup category;

    @Enumerated(EnumType.STRING)
    @Column(length = 32)
    private Equipment equipment;
}

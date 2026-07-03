package com.lifey.workout.exercise;

import com.lifey.common.domain.SyncableEntity;
import com.lifey.user.User;
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

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(nullable = false)
    private String name;

    @Enumerated(EnumType.STRING)
    @Column(length = 32)
    private MuscleGroup category;

    @Enumerated(EnumType.STRING)
    @Column(length = 32)
    private Equipment equipment;

    /**
     * Provenance for a copy created by the trainer content-assignment feature
     * (docs/personal_trainer/02-domain-es-migraciok.md, "Változás 3") — null for
     * every exercise a user created themselves. Not an FK: the trainer's original
     * may be soft-deleted later without invalidating the client's copy.
     */
    @Column(name = "origin_source_id")
    private Long originSourceId;

    @Column(name = "origin_trainer_id")
    private Long originTrainerId;
}

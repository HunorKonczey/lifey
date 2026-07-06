package com.lifey.workout.template;

import com.lifey.common.domain.SyncableEntity;
import com.lifey.user.User;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.util.ArrayList;
import java.util.List;

/**
 * Only the parent WorkoutTemplate is delta-synced (see
 * docs/16-delta-sync-rollout.md) — exercise links are never independently
 * tombstoned, so any link-only edit must explicitly bump {@code updatedAt}
 * (see WorkoutTemplateServiceImpl#update, which cannot rely on Hibernate
 * dirty-checking a template scalar field when only the exercise collection
 * changed).
 */
@Getter
@Setter
@Entity
@Table(name = "workout_templates")
public class WorkoutTemplate extends SyncableEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(nullable = false)
    private String name;

    @OneToMany(mappedBy = "workoutTemplate", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("sortOrder ASC")
    private List<WorkoutTemplateExercise> exercises = new ArrayList<>();

    /**
     * Provenance for a copy created by the trainer content-assignment feature
     * (docs/personal_trainer/02-domain-es-migraciok.md, "Változás 3") — null for
     * every template a user created themselves. Not an FK: the trainer's original
     * may be soft-deleted later without invalidating the client's copy.
     */
    @Column(name = "origin_source_id")
    private Long originSourceId;

    @Column(name = "origin_trainer_id")
    private Long originTrainerId;
}

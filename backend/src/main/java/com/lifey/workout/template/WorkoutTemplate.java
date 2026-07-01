package com.lifey.workout.template;

import com.lifey.common.domain.SyncableEntity;
import com.lifey.user.User;
import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OrderBy;
import jakarta.persistence.Table;
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
}

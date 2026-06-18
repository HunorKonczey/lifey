package com.lifey.workout.template;

import com.lifey.common.domain.BaseEntity;
import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.OneToMany;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

import java.util.ArrayList;
import java.util.List;

@Getter
@Setter
@Entity
@Table(name = "workout_templates")
public class WorkoutTemplate extends BaseEntity {

    @Column(nullable = false)
    private String name;

    @OneToMany(mappedBy = "workoutTemplate", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<WorkoutTemplateExercise> exercises = new ArrayList<>();
}

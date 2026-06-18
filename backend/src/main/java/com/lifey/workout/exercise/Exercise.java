package com.lifey.workout.exercise;

import com.lifey.common.domain.BaseEntity;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;

@Entity
@Table(name = "exercises")
public class Exercise extends BaseEntity {

    private String name;

    // Getters and setters.
}

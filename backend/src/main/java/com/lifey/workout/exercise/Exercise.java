package com.lifey.workout.exercise;

import com.lifey.common.domain.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@Entity
@Table(name = "exercises")
public class Exercise extends BaseEntity {

    @Column(nullable = false)
    private String name;
}

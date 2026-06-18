package com.lifey.weight;

import com.lifey.common.domain.BaseEntity;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;

import java.time.LocalDate;

@Entity
@Table(name = "weight_entries")
public class WeightEntry extends BaseEntity {

    private LocalDate date;

    private Double weight;

    // Getters and setters.
}

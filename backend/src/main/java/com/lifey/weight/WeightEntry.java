package com.lifey.weight;

import com.lifey.common.domain.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalDate;

@Getter
@Setter
@Entity
@Table(name = "weight_entries")
public class WeightEntry extends BaseEntity {

    @Column(name = "entry_date", nullable = false)
    private LocalDate date;

    @Column(nullable = false)
    private double weight;
}

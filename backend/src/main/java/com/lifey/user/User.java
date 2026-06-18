package com.lifey.user;

import com.lifey.common.domain.BaseEntity;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;

import java.time.Instant;

@Entity
@Table(name = "users")
public class User extends BaseEntity {

    private String email;

    private Instant createdAt;

    // Getters and setters.
}

package com.lifey.auth.dto;

import com.lifey.user.Role;

import java.time.Instant;
import java.util.Set;

public record UserResponse(
        Long id,
        String email,
        Set<Role> roles,
        Instant createdAt
) {
}

package com.lifey.superadmin.dto;

import java.time.Instant;
import java.util.Set;

public record SuperAdminUserResponse(
        Long id,
        String email,
        Set<String> roles,
        Instant createdAt,
        boolean hasAvatar
) {
}

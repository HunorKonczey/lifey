package com.lifey.superadmin.dto;

import com.lifey.user.Role;
import jakarta.validation.constraints.NotNull;

public record GrantRoleRequest(
        @NotNull
        Role role
) {
}

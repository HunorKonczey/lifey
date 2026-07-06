package com.lifey.superadmin;

import com.lifey.superadmin.dto.GrantRoleRequest;
import com.lifey.superadmin.dto.RoleAuditLogResponse;
import com.lifey.superadmin.dto.SuperAdminUserResponse;
import com.lifey.superadmin.service.RoleManagementService;
import com.lifey.user.Role;
import com.lifey.user.UserAvatar;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@Tag(name = "Super Admin", description = "User list and ROLE_TRAINER grant/revoke (super admin only)")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/superadmin/users")
public class SuperAdminUserController {

    private final RoleManagementService roleManagementService;

    @Operation(summary = "List users, paged and optionally searched by email")
    @GetMapping
    public Page<SuperAdminUserResponse> findUsers(
            @PageableDefault(size = 50, sort = "id") Pageable pageable,
            @Parameter(description = "Case-insensitive email contains-match")
            @RequestParam(required = false) String search) {
        return roleManagementService.findUsers(search, pageable);
    }

    @Operation(summary = "Grant a role to a user",
            description = "Only ROLE_TRAINER can be granted through this endpoint; any other role is 400. "
                    + "Idempotent: granting a role the user already has is a no-op, still 200.")
    @PostMapping("/{userId}/roles")
    public void grant(@PathVariable Long userId, @Valid @RequestBody GrantRoleRequest request) {
        roleManagementService.grant(userId, request.role());
    }

    @Operation(summary = "Revoke a role from a user")
    @DeleteMapping("/{userId}/roles/{role}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void revoke(@PathVariable Long userId, @PathVariable Role role) {
        roleManagementService.revoke(userId, role);
    }

    @Operation(summary = "Role-change history for a user")
    @GetMapping("/{userId}/role-audit")
    public List<RoleAuditLogResponse> findAuditLog(@PathVariable Long userId) {
        return roleManagementService.findAuditLog(userId);
    }

    @Operation(summary = "Get a user's profile picture", description = "404 if no picture is set.")
    @GetMapping("/{userId}/avatar")
    public ResponseEntity<byte[]> findAvatar(@PathVariable Long userId) {
        UserAvatar avatar = roleManagementService.findAvatar(userId);
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(avatar.getContentType()))
                .body(avatar.getImage());
    }
}

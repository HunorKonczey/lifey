package com.lifey.superadmin;

import com.lifey.superadmin.dto.GlobalRoleAuditResponse;
import com.lifey.superadmin.service.RoleManagementService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Super Admin", description = "Role-change history across all users (super admin only)")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/superadmin/role-audit")
public class SuperAdminRoleAuditController {

    private static final int MAX_PAGE_SIZE = 100;

    private final RoleManagementService roleManagementService;

    @Operation(summary = "Global role-change feed, newest first",
            description = "Each entry names who changed whose role. Always newest first; the sort parameter is not used.")
    @GetMapping
    public Page<GlobalRoleAuditResponse> findAll(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "30") int size) {
        Pageable pageable = PageRequest.of(Math.max(0, page), Math.min(Math.max(1, size), MAX_PAGE_SIZE));
        return roleManagementService.findGlobalAuditLog(pageable);
    }
}

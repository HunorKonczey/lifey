package com.lifey.superadmin;

import com.lifey.superadmin.dto.SuperAdminStatsResponse;
import com.lifey.superadmin.service.SuperAdminStatsService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Super Admin", description = "Account and trainer-request numbers (super admin only)")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/superadmin/stats")
public class SuperAdminStatsController {

    private final SuperAdminStatsService statsService;

    @Operation(summary = "Headline numbers: accounts, active accounts (30 days), trainers, clients with a trainer, pending requests")
    @GetMapping
    public SuperAdminStatsResponse stats() {
        return statsService.stats();
    }
}

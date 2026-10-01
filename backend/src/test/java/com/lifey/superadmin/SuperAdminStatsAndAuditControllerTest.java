package com.lifey.superadmin;

import com.lifey.superadmin.dto.GlobalRoleAuditResponse;
import com.lifey.superadmin.dto.SuperAdminStatsResponse;
import com.lifey.superadmin.service.RoleManagementService;
import com.lifey.superadmin.service.SuperAdminStatsService;
import com.lifey.user.Role;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.mockito.ArgumentCaptor;

import java.time.Instant;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest({SuperAdminStatsController.class, SuperAdminRoleAuditController.class})
class SuperAdminStatsAndAuditControllerTest {

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    SuperAdminStatsService statsService;

    @MockitoBean
    RoleManagementService roleManagementService;

    @Test
    void stats_returnsTheHeadlineNumbers() throws Exception {
        when(statsService.stats()).thenReturn(new SuperAdminStatsResponse(120, 64, 9, 41, 3, Instant.parse("2026-09-28T08:00:00Z")));

        mockMvc.perform(get("/api/v1/superadmin/stats"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalUsers").value(120))
                .andExpect(jsonPath("$.activeAccounts30d").value(64))
                .andExpect(jsonPath("$.trainers").value(9))
                .andExpect(jsonPath("$.clientsWithTrainer").value(41))
                .andExpect(jsonPath("$.pendingRequests").value(3))
                .andExpect(jsonPath("$.oldestPendingRequestAt").value("2026-09-28T08:00:00Z"));
    }

    @Test
    void roleAudit_returnsAPageOfNamedEntries() throws Exception {
        Pageable pageable = PageRequest.of(0, 30);
        when(roleManagementService.findGlobalAuditLog(any())).thenReturn(new PageImpl<>(List.of(new GlobalRoleAuditResponse(
                5L, 1L, "Admin Aranka", "admin@example.com", 2L, "Szabo Bence", "bence@example.com",
                Role.ROLE_TRAINER, RoleAuditAction.GRANT, Instant.parse("2026-08-12T10:00:00Z"))), pageable, 1));

        mockMvc.perform(get("/api/v1/superadmin/role-audit"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].targetName").value("Szabo Bence"))
                .andExpect(jsonPath("$.content[0].actorEmail").value("admin@example.com"))
                .andExpect(jsonPath("$.content[0].action").value("GRANT"));
    }

    @Test
    void roleAudit_clampsThePageSize() throws Exception {
        when(roleManagementService.findGlobalAuditLog(any())).thenReturn(new PageImpl<>(List.of()));

        mockMvc.perform(get("/api/v1/superadmin/role-audit?page=2&size=5000")).andExpect(status().isOk());

        ArgumentCaptor<Pageable> captor = ArgumentCaptor.forClass(Pageable.class);
        verify(roleManagementService).findGlobalAuditLog(captor.capture());
        assertThat(captor.getValue().getPageNumber()).isEqualTo(2);
        assertThat(captor.getValue().getPageSize()).isEqualTo(100);
    }
}

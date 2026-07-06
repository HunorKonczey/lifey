package com.lifey.superadmin;

import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.superadmin.dto.RoleAuditLogResponse;
import com.lifey.superadmin.dto.SuperAdminUserResponse;
import com.lifey.superadmin.exception.CannotModifySelfException;
import com.lifey.superadmin.exception.RoleNotManageableException;
import com.lifey.superadmin.service.RoleManagementService;
import com.lifey.user.Role;
import com.lifey.user.UserAvatar;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.List;
import java.util.Set;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(SuperAdminUserController.class)
class SuperAdminUserControllerTest {

    @Autowired
    MockMvc mockMvc;

    @MockitoBean
    RoleManagementService roleManagementService;

    @Test
    void findUsers_returnsPage() throws Exception {
        Pageable pageable = PageRequest.of(0, 50);
        when(roleManagementService.findUsers(any(), any())).thenReturn(new PageImpl<>(List.of(
                new SuperAdminUserResponse(2L, "client@example.com", Set.of("ROLE_USER"),
                        Instant.parse("2026-06-01T00:00:00Z"), false)), pageable, 1));

        mockMvc.perform(get("/api/v1/superadmin/users"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].email").value("client@example.com"));
    }

    @Test
    void grant_returnsOk() throws Exception {
        mockMvc.perform(post("/api/v1/superadmin/users/2/roles").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"role\":\"ROLE_TRAINER\"}"))
                .andExpect(status().isOk());
    }

    @Test
    void grant_notManageableRoleReturns400() throws Exception {
        doThrow(new RoleNotManageableException("nope")).when(roleManagementService).grant(2L, Role.ROLE_ADMIN);

        mockMvc.perform(post("/api/v1/superadmin/users/2/roles").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"role\":\"ROLE_ADMIN\"}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void grant_selfModificationReturns400() throws Exception {
        doThrow(new CannotModifySelfException("nope")).when(roleManagementService).grant(1L, Role.ROLE_TRAINER);

        mockMvc.perform(post("/api/v1/superadmin/users/1/roles").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"role\":\"ROLE_TRAINER\"}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void grant_missingRoleReturns400() throws Exception {
        mockMvc.perform(post("/api/v1/superadmin/users/2/roles").contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void revoke_returnsNoContent() throws Exception {
        mockMvc.perform(delete("/api/v1/superadmin/users/2/roles/ROLE_TRAINER"))
                .andExpect(status().isNoContent());
    }

    @Test
    void revoke_notGrantedReturns404() throws Exception {
        doThrow(new ResourceNotFoundException("nope")).when(roleManagementService).revoke(2L, Role.ROLE_TRAINER);

        mockMvc.perform(delete("/api/v1/superadmin/users/2/roles/ROLE_TRAINER"))
                .andExpect(status().isNotFound());
    }

    @Test
    void findAuditLog_returnsList() throws Exception {
        when(roleManagementService.findAuditLog(2L)).thenReturn(List.of(new RoleAuditLogResponse(
                5L, 1L, Role.ROLE_TRAINER, RoleAuditAction.GRANT, Instant.parse("2026-06-01T00:00:00Z"))));

        mockMvc.perform(get("/api/v1/superadmin/users/2/role-audit"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].action").value("GRANT"));
    }

    @Test
    void findAvatar_returnsImageBytes() throws Exception {
        UserAvatar avatar = new UserAvatar();
        avatar.setContentType("image/jpeg");
        avatar.setImage(new byte[]{1, 2, 3});
        when(roleManagementService.findAvatar(2L)).thenReturn(avatar);

        mockMvc.perform(get("/api/v1/superadmin/users/2/avatar"))
                .andExpect(status().isOk())
                .andExpect(header().string("Content-Type", "image/jpeg"));
    }

    @Test
    void findAvatar_returns404WhenMissing() throws Exception {
        when(roleManagementService.findAvatar(2L)).thenThrow(new ResourceNotFoundException("nope"));

        mockMvc.perform(get("/api/v1/superadmin/users/2/avatar"))
                .andExpect(status().isNotFound());
    }
}

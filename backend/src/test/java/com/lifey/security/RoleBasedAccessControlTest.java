package com.lifey.security;

import com.lifey.auth.service.JwtService;
import com.lifey.user.Role;
import com.lifey.user.User;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.util.HashSet;
import java.util.List;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Real end-to-end check of the role guards added for the personal-trainer
 * module (docs/personal_trainer/03-backend-terv.md, "Tesztek": "ROLE_USER a
 * /trainer/**-re → 403; ROLE_TRAINER a /superadmin/**-re → 403"). Every other
 * trainer/superadmin test in this codebase is a {@code @WebMvcTest} slice,
 * which never loads {@code SecurityConfig} — those tests exercise the
 * controllers' own logic but say nothing about whether the {@code hasRole(...)}
 * matchers actually reject the wrong role. This is the one test in the suite
 * that boots the full security filter chain (real {@code JwtAuthenticationFilter}
 * + real JWTs from {@link JwtService}) to prove the guards are wired, not just
 * documented.
 *
 * <p>No persisted users are needed: {@code JwtAuthenticationFilter} builds the
 * {@code UserPrincipal} entirely from the JWT's own claims (see its Javadoc) —
 * it never re-queries the database per request — so a freshly constructed,
 * never-saved {@link User} is enough to mint a token with whatever roles a
 * test wants to assert against.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
class RoleBasedAccessControlTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>("postgres:16");

    @Autowired
    MockMvc mockMvc;

    @Autowired
    JwtService jwtService;

    @Test
    void plainUser_isForbiddenFromTrainerEndpoints() throws Exception {
        mockMvc.perform(get("/api/v1/trainer/clients").header("Authorization", "Bearer " + tokenFor(1L, Role.ROLE_USER)))
                .andExpect(status().isForbidden());
    }

    @Test
    void trainer_canAccessTrainerEndpoints() throws Exception {
        mockMvc.perform(get("/api/v1/trainer/clients")
                        .header("Authorization", "Bearer " + tokenFor(2L, Role.ROLE_USER, Role.ROLE_TRAINER)))
                .andExpect(status().isOk());
    }

    @Test
    void trainer_isForbiddenFromSuperAdminEndpoints() throws Exception {
        mockMvc.perform(get("/api/v1/superadmin/users")
                        .header("Authorization", "Bearer " + tokenFor(2L, Role.ROLE_USER, Role.ROLE_TRAINER)))
                .andExpect(status().isForbidden());
    }

    @Test
    void superAdmin_canAccessSuperAdminEndpoints() throws Exception {
        mockMvc.perform(get("/api/v1/superadmin/users")
                        .header("Authorization", "Bearer " + tokenFor(3L, Role.ROLE_USER, Role.ROLE_SUPER_ADMIN)))
                .andExpect(status().isOk());
    }

    @Test
    void plainUser_isForbiddenFromSuperAdminEndpointsToo() throws Exception {
        mockMvc.perform(get("/api/v1/superadmin/users").header("Authorization", "Bearer " + tokenFor(1L, Role.ROLE_USER)))
                .andExpect(status().isForbidden());
    }

    @Test
    void unauthenticatedRequest_isRejectedOnTrainerEndpoints() throws Exception {
        mockMvc.perform(get("/api/v1/trainer/clients"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void plainUser_canStillAccessTheClientSideTrainerInviteEndpoints() throws Exception {
        // The client-side (mobile) counterparts stay on the plain ROLE_USER
        // `authenticated()` rule, not the ROLE_TRAINER guard — confirm they're
        // not accidentally caught by the /api/v1/trainer/** matcher.
        mockMvc.perform(get("/api/v1/trainer-invites/pending")
                        .header("Authorization", "Bearer " + tokenFor(1L, Role.ROLE_USER)))
                .andExpect(status().isOk());
    }

    private String tokenFor(Long userId, Role... roles) {
        User user = new User();
        user.setId(userId);
        user.setEmail("user" + userId + "@example.com");
        user.setRoles(new HashSet<>(List.of(roles)));
        return jwtService.generateAccessToken(user);
    }
}

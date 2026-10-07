package com.lifey.idempotency;

import com.lifey.auth.service.JwtService;
import com.lifey.idempotency.service.IdempotencyService;
import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.HashSet;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * {@code Idempotency-Key} through the real security chain and schema: a POST the outbox repeats after a lost
 * answer must not create the entity twice, and must still be given the id of the first one.
 */
@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
class IdempotencyFilterIntegrationTest {

    @Container
    @ServiceConnection
    static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer("postgres:16");

    @Autowired
    MockMvc mockMvc;

    @Autowired
    JwtService jwtService;

    @Autowired
    UserRepository userRepository;

    @Autowired
    IdempotencyKeyRepository keyRepository;

    @Autowired
    IdempotencyService idempotencyService;

    @Autowired
    JdbcTemplate jdbc;

    @Test
    void aRepeatedKey_isAnsweredWithTheFirstResponseAndCreatesNothingNew() throws Exception {
        User user = saveUser();
        String key = UUID.randomUUID().toString();

        MvcResult first = mockMvc.perform(weight(user, key, 80.5))
                .andExpect(status().isCreated())
                .andExpect(header().doesNotExist("Idempotent-Replayed"))
                .andReturn();
        // Same key, even with a different body: a retry is the same operation, whatever the client now holds.
        MvcResult second = mockMvc.perform(weight(user, key, 99.9))
                .andExpect(status().isCreated())
                .andExpect(header().string("Idempotent-Replayed", "true"))
                .andExpect(jsonPath("$.weight").value(80.5))
                .andReturn();

        assertThat(second.getResponse().getContentAsString()).isEqualTo(first.getResponse().getContentAsString());
        assertThat(weightCount(user)).isEqualTo(1);
    }

    @Test
    void differentKeys_areDifferentOperations() throws Exception {
        User user = saveUser();

        mockMvc.perform(weight(user, UUID.randomUUID().toString(), 80.0)).andExpect(status().isCreated());
        mockMvc.perform(weight(user, UUID.randomUUID().toString(), 80.0)).andExpect(status().isCreated());

        assertThat(weightCount(user)).isEqualTo(2);
    }

    @Test
    void withoutAKey_nothingIsDeduplicated() throws Exception {
        User user = saveUser();

        mockMvc.perform(weight(user, null, 80.0)).andExpect(status().isCreated());
        mockMvc.perform(weight(user, null, 80.0)).andExpect(status().isCreated());

        assertThat(weightCount(user)).isEqualTo(2);
    }

    @Test
    void theSameKeyOfAnotherUser_isAnotherOperation() throws Exception {
        User alice = saveUser();
        User bob = saveUser();
        String key = UUID.randomUUID().toString();

        mockMvc.perform(weight(alice, key, 60.0)).andExpect(status().isCreated());
        mockMvc.perform(weight(bob, key, 90.0))
                .andExpect(status().isCreated())
                .andExpect(header().doesNotExist("Idempotent-Replayed"))
                .andExpect(jsonPath("$.weight").value(90.0));

        assertThat(weightCount(alice)).isEqualTo(1);
        assertThat(weightCount(bob)).isEqualTo(1);
    }

    @Test
    void aFailedRequest_freesItsKeySoTheRetryRunsForReal() throws Exception {
        User user = saveUser();
        String key = UUID.randomUUID().toString();

        mockMvc.perform(weight(user, key, -1.0)).andExpect(status().isBadRequest());
        assertThat(keyRepository.findByUserIdAndIdemKey(user.getId(), key)).isEmpty();

        mockMvc.perform(weight(user, key, 70.0))
                .andExpect(status().isCreated())
                .andExpect(header().doesNotExist("Idempotent-Replayed"));
        assertThat(weightCount(user)).isEqualTo(1);
    }

    @Test
    void aKeyReusedForAnotherRequest_isRefused() throws Exception {
        User user = saveUser();
        String key = UUID.randomUUID().toString();

        mockMvc.perform(weight(user, key, 80.0)).andExpect(status().isCreated());
        mockMvc.perform(post("/api/v1/water-entries")
                        .header("Authorization", "Bearer " + jwtService.generateAccessToken(user))
                        .header("Idempotency-Key", key)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"consumedAt\":\"" + Instant.now().minusSeconds(60) + "\",\"volumeLiters\":0.5}"))
                .andExpect(status().isUnprocessableEntity());
    }

    @Test
    void aRequestStillInFlight_isTurnedAwayWithAConflict() throws Exception {
        User user = saveUser();
        String key = UUID.randomUUID().toString();
        claimWithoutAnswer(user, key);

        mockMvc.perform(weight(user, key, 80.0))
                .andExpect(status().isConflict())
                .andExpect(header().string("Retry-After", "2"));
        assertThat(weightCount(user)).isZero();
    }

    @Test
    void aRequestThatNeverAnswered_isTakenOverOnceItIsStale() throws Exception {
        User user = saveUser();
        String key = UUID.randomUUID().toString();
        claimWithoutAnswer(user, key);
        jdbc.update("update idempotency_keys set created_at = now() - interval '10 minutes' where idem_key = ?", key);

        mockMvc.perform(weight(user, key, 80.0)).andExpect(status().isCreated());

        assertThat(weightCount(user)).isEqualTo(1);
        assertThat(keyRepository.findByUserIdAndIdemKey(user.getId(), key)).get()
                .extracting(IdempotencyKey::getResponseStatus).isEqualTo(201);
    }

    @Test
    void withoutAUser_theKeyDoesNotMatter() throws Exception {
        mockMvc.perform(post("/api/v1/weights")
                        .header("Idempotency-Key", UUID.randomUUID().toString())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void theSweepRemovesOnlyOldKeys() throws Exception {
        User user = saveUser();
        String old = UUID.randomUUID().toString();
        String fresh = UUID.randomUUID().toString();
        mockMvc.perform(weight(user, old, 80.0)).andExpect(status().isCreated());
        mockMvc.perform(weight(user, fresh, 80.0)).andExpect(status().isCreated());
        jdbc.update("update idempotency_keys set created_at = now() - interval '30 days' where idem_key = ?", old);

        idempotencyService.deleteExpired();

        assertThat(keyRepository.findByUserIdAndIdemKey(user.getId(), old)).isEmpty();
        assertThat(keyRepository.findByUserIdAndIdemKey(user.getId(), fresh)).isPresent();
    }

    private MockHttpServletRequestBuilder weight(User user, String key, double kilos) {
        MockHttpServletRequestBuilder request = post("/api/v1/weights")
                .header("Authorization", "Bearer " + jwtService.generateAccessToken(user))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"date\":\"" + LocalDate.now(ZoneOffset.UTC) + "\",\"weight\":" + kilos + "}");
        return key == null ? request : request.header("Idempotency-Key", key);
    }

    private int weightCount(User user) {
        Integer count = jdbc.queryForObject("select count(*) from weight_entries where user_id = ?", Integer.class, user.getId());
        return count == null ? 0 : count;
    }

    /** A request that claimed the key and has not answered (yet, or ever): what a concurrent duplicate meets. */
    private void claimWithoutAnswer(User user, String key) {
        idempotencyService.claim(user.getId(), key, "POST", "/api/v1/weights");
    }

    private User saveUser() {
        User user = new User();
        user.setEmail("idempotency-" + System.nanoTime() + "@example.com");
        user.setPasswordHash("irrelevant");
        user.setCreatedAt(Instant.now());
        user.setRoles(new HashSet<>(List.of(Role.ROLE_USER)));
        return userRepository.save(user);
    }
}

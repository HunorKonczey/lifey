package com.lifey.sleep.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.DuplicateResourceException;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.sleep.SleepSession;
import com.lifey.sleep.SleepSessionRepository;
import com.lifey.sleep.dto.SleepSessionRequest;
import com.lifey.sleep.dto.SleepSessionResponse;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** docs/integrations/89 G2.1: ownership, the import dedupe and the delta feed of sleep sessions. */
@ExtendWith(MockitoExtension.class)
class SleepSessionServiceImplTest {

    private static final Long USER_ID = 1L;
    private static final Instant START = Instant.parse("2026-11-20T22:40:00Z");
    private static final Instant END = Instant.parse("2026-11-21T06:10:00Z");

    @Mock
    SleepSessionRepository repository;

    @Mock
    UserRepository userRepository;

    @Mock
    CurrentUserProvider currentUserProvider;

    @InjectMocks
    SleepSessionServiceImpl service;

    @BeforeEach
    void stubCurrentUser() {
        lenient().when(currentUserProvider.getUserId()).thenReturn(USER_ID);
        lenient().when(userRepository.getReferenceById(USER_ID)).thenReturn(new User());
    }

    private static SleepSessionRequest night(String recordId, String app) {
        return new SleepSessionRequest(START, END, 420, 80, 230, 110, 30, app, recordId);
    }

    @Test
    void create_attachesTheCurrentUserAndMapsEveryField() {
        when(repository.save(any(SleepSession.class))).thenAnswer(inv -> inv.getArgument(0));

        SleepSessionResponse response = service.create(night("hc-sleep-1", "  Garmin Connect "));

        ArgumentCaptor<SleepSession> saved = ArgumentCaptor.forClass(SleepSession.class);
        verify(repository).save(saved.capture());
        SleepSession session = saved.getValue();
        assertThat(session.getUser()).isNotNull();
        assertThat(session.getStartedAt()).isEqualTo(START);
        assertThat(session.getEndedAt()).isEqualTo(END);
        assertThat(session.getDeepMinutes()).isEqualTo(80);
        assertThat(session.getSourceAppName()).isEqualTo("Garmin Connect");
        assertThat(response.healthRecordId()).isEqualTo("hc-sleep-1");
        assertThat(response.remMinutes()).isEqualTo(110);
    }

    @Test
    void create_withoutStagesKeepsThemNull() {
        when(repository.save(any(SleepSession.class))).thenAnswer(inv -> inv.getArgument(0));

        SleepSessionResponse response =
                service.create(new SleepSessionRequest(START, END, null, null, null, null, null, " ", ""));

        assertThat(response.deepMinutes()).isNull();
        assertThat(response.asleepMinutes()).isNull();
        assertThat(response.sourceAppName()).isNull();
        // A blank record id is no dedupe key, so nothing is looked up.
        assertThat(response.healthRecordId()).isNull();
        verify(repository, never()).existsByUserIdAndHealthRecordId(any(), anyString());
    }

    @Test
    void create_aRecordTheUserAlreadyHasIsAConflictAndNothingIsSaved() {
        when(repository.existsByUserIdAndHealthRecordId(USER_ID, "hc-sleep-1")).thenReturn(true);

        assertThatThrownBy(() -> service.create(night("hc-sleep-1", "Garmin Connect")))
                .isInstanceOf(DuplicateResourceException.class)
                .hasMessageContaining("hc-sleep-1");
        verify(repository, never()).save(any());
    }

    @Test
    void findAll_readsOnlyTheCurrentUsersLiveSessions() {
        SleepSession session = new SleepSession();
        session.setStartedAt(START);
        session.setEndedAt(END);
        when(repository.findAllByUserIdAndDeletedAtIsNullOrderByEndedAtDesc(USER_ID)).thenReturn(List.of(session));

        assertThat(service.findAll()).singleElement().extracting(SleepSessionResponse::endedAt).isEqualTo(END);
    }

    @Test
    void findDelta_forcesTheUpdatedAtIdOrderWhateverTheClientAsked() {
        Instant since = Instant.parse("2026-11-20T00:00:00Z");
        when(repository.findByUserIdAndUpdatedAtGreaterThanEqual(eq(USER_ID), eq(since), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of()));

        service.findDelta(since, PageRequest.of(1, 50, Sort.by("endedAt").descending()));

        ArgumentCaptor<Pageable> pageable = ArgumentCaptor.forClass(Pageable.class);
        verify(repository).findByUserIdAndUpdatedAtGreaterThanEqual(eq(USER_ID), eq(since), pageable.capture());
        assertThat(pageable.getValue().getPageNumber()).isEqualTo(1);
        assertThat(pageable.getValue().getPageSize()).isEqualTo(50);
        assertThat(pageable.getValue().getSort())
                .isEqualTo(Sort.by(Sort.Order.asc("updatedAt"), Sort.Order.asc("id")));
    }

    @Test
    void delete_setsATombstoneInsteadOfRemoving() {
        SleepSession session = new SleepSession();
        when(repository.findByIdAndUserId(7L, USER_ID)).thenReturn(Optional.of(session));

        service.delete(7L);

        assertThat(session.getDeletedAt()).isNotNull();
        verify(repository, never()).delete(any());
        verify(repository, never()).deleteById(any());
    }

    @Test
    void delete_anotherUsersSessionIsNotFound() {
        when(repository.findByIdAndUserId(8L, USER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.delete(8L)).isInstanceOf(ResourceNotFoundException.class);
    }
}

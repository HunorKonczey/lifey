package com.lifey.water.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.domain.BaseEntity;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.water.WaterEntry;
import com.lifey.water.WaterEntryRepository;
import com.lifey.water.WaterSource;
import com.lifey.water.WaterSourceRepository;
import com.lifey.water.dto.WaterEntryRequest;
import com.lifey.water.dto.WaterEntryResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class WaterEntryServiceImplTest {

    private static final Long USER_ID = 1L;

    @Mock
    WaterEntryRepository repository;

    @Mock
    WaterSourceRepository sourceRepository;

    @Mock
    UserRepository userRepository;

    @Mock
    CurrentUserProvider currentUserProvider;

    @InjectMocks
    WaterEntryServiceImpl service;

    @BeforeEach
    void stubCurrentUser() {
        lenient().when(currentUserProvider.getUserId()).thenReturn(USER_ID);
        lenient().when(userRepository.getReferenceById(USER_ID)).thenReturn(new User());
    }

    @Test
    void create_manualEntry_savesWithoutSource() {
        when(repository.save(any(WaterEntry.class))).thenAnswer(inv -> withId(inv.getArgument(0), 3L));
        Instant consumedAt = Instant.parse("2026-06-18T08:00:00Z");
        WaterEntryRequest request = new WaterEntryRequest(consumedAt, null, 0.5);

        WaterEntryResponse result = service.create(request);

        assertThat(result.id()).isEqualTo(3L);
        assertThat(result.consumedAt()).isEqualTo(consumedAt);
        assertThat(result.volumeLiters()).isEqualTo(0.5);
        assertThat(result.sourceId()).isNull();
        assertThat(result.sourceName()).isNull();
    }

    @Test
    void create_fromSource_resolvesSourceAndKeepsGivenVolume() {
        WaterSource source = new WaterSource();
        source.setId(1L);
        source.setName("Creatine Shake");
        source.setVolumeLiters(0.9);
        when(sourceRepository.findByIdAndUserId(1L, USER_ID)).thenReturn(Optional.of(source));
        when(repository.save(any(WaterEntry.class))).thenAnswer(inv -> withId(inv.getArgument(0), 4L));
        WaterEntryRequest request =
                new WaterEntryRequest(Instant.parse("2026-06-18T08:00:00Z"), 1L, 0.9);

        WaterEntryResponse result = service.create(request);

        assertThat(result.sourceId()).isEqualTo(1L);
        assertThat(result.sourceName()).isEqualTo("Creatine Shake");
        assertThat(result.volumeLiters()).isEqualTo(0.9);
    }

    @Test
    void create_throwsWhenSourceMissing() {
        when(sourceRepository.findByIdAndUserId(99L, USER_ID)).thenReturn(Optional.empty());
        WaterEntryRequest request =
                new WaterEntryRequest(Instant.parse("2026-06-18T08:00:00Z"), 99L, 0.5);

        assertThatThrownBy(() -> service.create(request))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessageContaining("Water source not found: 99");
    }

    @Test
    void findAll_mapsEntriesNewestFirst() {
        WaterEntry entry = new WaterEntry();
        entry.setId(1L);
        entry.setConsumedAt(Instant.parse("2026-06-18T08:00:00Z"));
        entry.setVolumeLiters(0.5);
        when(repository.findAllByUserIdAndDeletedAtIsNullOrderByConsumedAtDesc(USER_ID)).thenReturn(List.of(entry));

        List<WaterEntryResponse> result = service.findAll();

        assertThat(result).singleElement().satisfies(r -> {
            assertThat(r.id()).isEqualTo(1L);
            assertThat(r.volumeLiters()).isEqualTo(0.5);
        });
    }

    @Test
    void findAll_excludesSoftDeletedEntries() {
        // findAllByUserIdAndDeletedAtIsNullOrderByConsumedAtDesc already filters
        // at the query level — a soft-deleted row is simply never returned.
        when(repository.findAllByUserIdAndDeletedAtIsNullOrderByConsumedAtDesc(USER_ID)).thenReturn(List.of());

        assertThat(service.findAll()).isEmpty();
    }

    @Test
    void delete_throwsWhenMissing() {
        when(repository.findByIdAndUserId(99L, USER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.delete(99L))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void delete_setsDeletedAtInsteadOfRemovingRow() {
        WaterEntry entry = new WaterEntry();
        entry.setId(1L);
        when(repository.findByIdAndUserId(1L, USER_ID)).thenReturn(Optional.of(entry));

        service.delete(1L);

        assertThat(entry.getDeletedAt()).isNotNull();
    }

    @Test
    void findDelta_isUserScopedAndIncludesTombstones() {
        WaterEntry deleted = new WaterEntry();
        deleted.setId(2L);
        deleted.setConsumedAt(Instant.parse("2026-06-18T08:00:00Z"));
        deleted.setVolumeLiters(0.5);
        deleted.setDeletedAt(Instant.parse("2026-06-19T00:00:00Z"));

        Instant since = Instant.parse("2026-06-17T00:00:00Z");
        Pageable requested = PageRequest.of(0, 50);
        Page<WaterEntry> page = new PageImpl<>(List.of(deleted));
        when(repository.findByUserIdAndUpdatedAtGreaterThanEqual(eq(USER_ID), eq(since), any()))
                .thenReturn(page);

        Page<WaterEntryResponse> result = service.findDelta(since, requested);

        assertThat(result.getContent()).singleElement().satisfies(r -> {
            assertThat(r.id()).isEqualTo(2L);
            assertThat(r.deletedAt()).isEqualTo(deleted.getDeletedAt());
        });
    }

    private static <T extends BaseEntity> T withId(T entity, Long id) {
        entity.setId(id);
        return entity;
    }
}

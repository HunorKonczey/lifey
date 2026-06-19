package com.lifey.water;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.water.dto.WaterEntryRequest;
import com.lifey.water.dto.WaterEntryResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
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
        when(repository.save(any(WaterEntry.class))).thenAnswer(inv -> {
            WaterEntry e = inv.getArgument(0);
            e.setId(3L);
            return e;
        });
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
        when(repository.save(any(WaterEntry.class))).thenAnswer(inv -> {
            WaterEntry e = inv.getArgument(0);
            e.setId(4L);
            return e;
        });
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
        when(repository.findAllByUserIdOrderByConsumedAtDesc(USER_ID)).thenReturn(List.of(entry));

        List<WaterEntryResponse> result = service.findAll();

        assertThat(result).singleElement().satisfies(r -> {
            assertThat(r.id()).isEqualTo(1L);
            assertThat(r.volumeLiters()).isEqualTo(0.5);
        });
    }

    @Test
    void delete_throwsWhenMissing() {
        when(repository.existsByIdAndUserId(99L, USER_ID)).thenReturn(false);

        assertThatThrownBy(() -> service.delete(99L))
                .isInstanceOf(ResourceNotFoundException.class);
    }
}

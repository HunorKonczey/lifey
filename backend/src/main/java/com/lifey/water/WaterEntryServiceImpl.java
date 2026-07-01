package com.lifey.water;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.user.UserRepository;
import com.lifey.water.dto.WaterEntryRequest;
import com.lifey.water.dto.WaterEntryResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;

@Service
@Transactional
public class WaterEntryServiceImpl implements WaterEntryService {

    private final WaterEntryRepository repository;
    private final WaterSourceRepository sourceRepository;
    private final UserRepository userRepository;
    private final CurrentUserProvider currentUserProvider;

    public WaterEntryServiceImpl(WaterEntryRepository repository, WaterSourceRepository sourceRepository,
                                 UserRepository userRepository, CurrentUserProvider currentUserProvider) {
        this.repository = repository;
        this.sourceRepository = sourceRepository;
        this.userRepository = userRepository;
        this.currentUserProvider = currentUserProvider;
    }

    @Override
    @Transactional(readOnly = true)
    public List<WaterEntryResponse> findAll() {
        return repository.findAllByUserIdAndDeletedAtIsNullOrderByConsumedAtDesc(currentUserProvider.getUserId()).stream()
                .map(WaterEntryMapper::toResponse)
                .toList();
    }

    @Override
    @Transactional(readOnly = true)
    public Page<WaterEntryResponse> findDelta(Instant updatedSince, Pageable pageable) {
        // Delta-sync feed: fixed ordering, includes tombstoned rows — see
        // docs/16-delta-sync-rollout.md and WaterEntryRepository.findByUserIdAndUpdatedAtGreaterThanEqual.
        Pageable deltaPageable = PageRequest.of(
                pageable.getPageNumber(),
                pageable.getPageSize(),
                Sort.by(Sort.Order.asc("updatedAt"), Sort.Order.asc("id")));
        return repository.findByUserIdAndUpdatedAtGreaterThanEqual(currentUserProvider.getUserId(), updatedSince, deltaPageable)
                .map(WaterEntryMapper::toResponse);
    }

    @Override
    public WaterEntryResponse create(WaterEntryRequest request) {
        Long userId = currentUserProvider.getUserId();
        WaterEntry entry = new WaterEntry();
        entry.setUser(userRepository.getReferenceById(userId));
        entry.setConsumedAt(request.consumedAt());
        entry.setVolumeLiters(request.volumeLiters());

        if (request.sourceId() != null) {
            WaterSource source = sourceRepository.findByIdAndUserId(request.sourceId(), userId)
                    .orElseThrow(() -> new ResourceNotFoundException("Water source not found: " + request.sourceId()));
            entry.setWaterSource(source);
        }

        return WaterEntryMapper.toResponse(repository.save(entry));
    }

    @Override
    public void delete(Long id) {
        Long userId = currentUserProvider.getUserId();
        WaterEntry entry = repository.findByIdAndUserId(id, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Water entry not found: " + id));
        entry.setDeletedAt(Instant.now());
    }
}

package com.lifey.weight.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.user.UserRepository;
import com.lifey.weight.WeightEntry;
import com.lifey.weight.WeightEntryRepository;
import com.lifey.weight.WeightMapper;
import com.lifey.weight.dto.WeightRequest;
import com.lifey.weight.dto.WeightResponse;
import lombok.RequiredArgsConstructor;
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
@RequiredArgsConstructor
public class WeightServiceImpl implements WeightService {

    private final WeightEntryRepository repository;
    private final UserRepository userRepository;
    private final CurrentUserProvider currentUserProvider;

    @Override
    @Transactional(readOnly = true)
    public List<WeightResponse> findAll() {
        return repository.findAllByUserIdAndDeletedAtIsNullOrderByDateDescRecordedAtDesc(currentUserProvider.getUserId()).stream()
                .map(WeightMapper::toResponse)
                .toList();
    }

    @Override
    @Transactional(readOnly = true)
    public Page<WeightResponse> findDelta(Instant updatedSince, Pageable pageable) {
        // Delta-sync feed: fixed ordering, includes tombstoned rows — see
        // docs/16-delta-sync-rollout.md and WeightEntryRepository.findByUserIdAndUpdatedAtGreaterThanEqual.
        Pageable deltaPageable = PageRequest.of(
                pageable.getPageNumber(),
                pageable.getPageSize(),
                Sort.by(Sort.Order.asc("updatedAt"), Sort.Order.asc("id")));
        return repository.findByUserIdAndUpdatedAtGreaterThanEqual(currentUserProvider.getUserId(), updatedSince, deltaPageable)
                .map(WeightMapper::toResponse);
    }

    @Override
    public WeightResponse create(WeightRequest request) {
        WeightEntry entry = WeightMapper.toEntity(request);
        entry.setUser(userRepository.getReferenceById(currentUserProvider.getUserId()));
        // Stamp the recording instant server-side so same-day entries keep their order.
        entry.setRecordedAt(Instant.now());
        WeightEntry saved = repository.save(entry);
        return WeightMapper.toResponse(saved);
    }

    @Override
    public void delete(Long id) {
        Long userId = currentUserProvider.getUserId();
        WeightEntry entry = repository.findByIdAndUserId(id, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Weight entry not found: " + id));
        entry.setDeletedAt(Instant.now());
    }
}

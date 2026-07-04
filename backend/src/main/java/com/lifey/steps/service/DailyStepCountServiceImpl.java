package com.lifey.steps.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.steps.DailyStepCount;
import com.lifey.steps.DailyStepCountMapper;
import com.lifey.steps.DailyStepCountRepository;
import com.lifey.steps.dto.DailyStepCountRequest;
import com.lifey.steps.dto.DailyStepCountResponse;
import com.lifey.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional
public class DailyStepCountServiceImpl implements DailyStepCountService {

    private final DailyStepCountRepository repository;
    private final UserRepository userRepository;
    private final CurrentUserProvider currentUserProvider;

    @Override
    @Transactional(readOnly = true)
    public List<DailyStepCountResponse> findAll() {
        return repository.findAllByUserIdAndDeletedAtIsNullOrderByDateDesc(currentUserProvider.getUserId()).stream()
                .map(DailyStepCountMapper::toResponse)
                .toList();
    }

    @Override
    @Transactional(readOnly = true)
    public List<DailyStepCountResponse> findAll(LocalDate from, LocalDate to) {
        return findAllForUser(currentUserProvider.getUserId(), from, to);
    }

    @Override
    @Transactional(readOnly = true)
    public List<DailyStepCountResponse> findAllForUser(Long userId, LocalDate from, LocalDate to) {
        return repository.findByUserIdAndDeletedAtIsNullAndDateRange(userId, from, to).stream()
                .map(DailyStepCountMapper::toResponse)
                .toList();
    }

    @Override
    @Transactional(readOnly = true)
    public Page<DailyStepCountResponse> findDelta(Instant updatedSince, Pageable pageable) {
        // Delta-sync feed: fixed ordering, includes tombstoned rows — see
        // docs/16-delta-sync-rollout.md and DailyStepCountRepository.findByUserIdAndUpdatedAtGreaterThanEqual.
        Pageable deltaPageable = PageRequest.of(
                pageable.getPageNumber(),
                pageable.getPageSize(),
                Sort.by(Sort.Order.asc("updatedAt"), Sort.Order.asc("id")));
        return repository.findByUserIdAndUpdatedAtGreaterThanEqual(currentUserProvider.getUserId(), updatedSince, deltaPageable)
                .map(DailyStepCountMapper::toResponse);
    }

    @Override
    public DailyStepCountResponse create(DailyStepCountRequest request) {
        Long userId = currentUserProvider.getUserId();
        // Upsert keyed on (user, date): a day's step total is rewritten as steps
        // accumulate, so re-posting the same date updates the row instead of
        // inserting a duplicate (which the unique (user_id, entry_date) index forbids).
        // findByUserIdAndDate is deliberately not deletedAt-filtered, so re-posting a
        // previously deleted date revives the existing row instead of violating the
        // unique constraint with a fresh insert.
        DailyStepCount entry = repository.findByUserIdAndDate(userId, request.date())
                .orElseGet(() -> {
                    DailyStepCount created = DailyStepCountMapper.toEntity(request);
                    created.setUser(userRepository.getReferenceById(userId));
                    return created;
                });
        entry.setSteps(request.steps());
        entry.setDeletedAt(null);
        DailyStepCount saved = repository.save(entry);
        return DailyStepCountMapper.toResponse(saved);
    }

    @Override
    public DailyStepCountResponse update(Long id, DailyStepCountRequest request) {
        Long userId = currentUserProvider.getUserId();
        DailyStepCount entry = repository.findByIdAndUserId(id, userId)
                .filter(e -> e.getDeletedAt() == null)
                .orElseThrow(() -> new ResourceNotFoundException("Daily step count not found: " + id));
        entry.setDate(request.date());
        entry.setSteps(request.steps());
        DailyStepCount saved = repository.save(entry);
        return DailyStepCountMapper.toResponse(saved);
    }

    @Override
    public void delete(Long id) {
        Long userId = currentUserProvider.getUserId();
        DailyStepCount entry = repository.findByIdAndUserId(id, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Daily step count not found: " + id));
        entry.setDeletedAt(Instant.now());
    }
}

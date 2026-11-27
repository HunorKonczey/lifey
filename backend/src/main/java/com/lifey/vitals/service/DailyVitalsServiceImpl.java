package com.lifey.vitals.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.common.util.DateRanges;
import com.lifey.user.UserRepository;
import com.lifey.vitals.DailyVitals;
import com.lifey.vitals.DailyVitalsMapper;
import com.lifey.vitals.DailyVitalsRepository;
import com.lifey.vitals.dto.DailyVitalsRequest;
import com.lifey.vitals.dto.DailyVitalsResponse;
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
public class DailyVitalsServiceImpl implements DailyVitalsService {

    private final DailyVitalsRepository repository;
    private final UserRepository userRepository;
    private final CurrentUserProvider currentUserProvider;

    @Override
    @Transactional(readOnly = true)
    public List<DailyVitalsResponse> findAll() {
        return repository.findAllByUserIdAndDeletedAtIsNullOrderByDateDesc(currentUserProvider.getUserId()).stream()
                .map(DailyVitalsMapper::toResponse)
                .toList();
    }

    @Override
    @Transactional(readOnly = true)
    public List<DailyVitalsResponse> findAll(LocalDate from, LocalDate to) {
        return repository.findByUserIdAndDeletedAtIsNullAndDateRange(
                        currentUserProvider.getUserId(),
                        from != null ? from : DateRanges.DISTANT_PAST,
                        to != null ? to : DateRanges.DISTANT_FUTURE).stream()
                .map(DailyVitalsMapper::toResponse)
                .toList();
    }

    @Override
    @Transactional(readOnly = true)
    public Page<DailyVitalsResponse> findDelta(Instant updatedSince, Pageable pageable) {
        Pageable deltaPageable = PageRequest.of(pageable.getPageNumber(), pageable.getPageSize(),
                Sort.by(Sort.Order.asc("updatedAt"), Sort.Order.asc("id")));
        return repository.findByUserIdAndUpdatedAtGreaterThanEqual(currentUserProvider.getUserId(), updatedSince,
                deltaPageable).map(DailyVitalsMapper::toResponse);
    }

    @Override
    public DailyVitalsResponse create(DailyVitalsRequest request) {
        Long userId = currentUserProvider.getUserId();
        // Upsert on (user, date), like the daily step counts: the unique index allows one row per day, and a deleted
        // day is revived rather than inserted again.
        DailyVitals vitals = repository.findByUserIdAndDate(userId, request.date())
                .orElseGet(() -> {
                    DailyVitals created = new DailyVitals();
                    created.setUser(userRepository.getReferenceById(userId));
                    return created;
                });
        DailyVitalsMapper.apply(vitals, request);
        vitals.setDeletedAt(null);
        return DailyVitalsMapper.toResponse(repository.save(vitals));
    }

    @Override
    public DailyVitalsResponse update(Long id, DailyVitalsRequest request) {
        DailyVitals vitals = repository.findByIdAndUserId(id, currentUserProvider.getUserId())
                .filter(v -> v.getDeletedAt() == null)
                .orElseThrow(() -> new ResourceNotFoundException("Daily vitals not found: " + id));
        DailyVitalsMapper.apply(vitals, request);
        return DailyVitalsMapper.toResponse(repository.save(vitals));
    }

    @Override
    public void delete(Long id) {
        DailyVitals vitals = repository.findByIdAndUserId(id, currentUserProvider.getUserId())
                .orElseThrow(() -> new ResourceNotFoundException("Daily vitals not found: " + id));
        vitals.setDeletedAt(Instant.now());
    }
}

package com.lifey.sleep.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.DuplicateResourceException;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.sleep.SleepSession;
import com.lifey.sleep.SleepSessionMapper;
import com.lifey.sleep.SleepSessionRepository;
import com.lifey.sleep.dto.SleepSessionRequest;
import com.lifey.sleep.dto.SleepSessionResponse;
import com.lifey.user.UserRepository;
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
public class SleepSessionServiceImpl implements SleepSessionService {

    private final SleepSessionRepository repository;
    private final UserRepository userRepository;
    private final CurrentUserProvider currentUserProvider;

    @Override
    @Transactional(readOnly = true)
    public List<SleepSessionResponse> findAll() {
        return repository.findAllByUserIdAndDeletedAtIsNullOrderByEndedAtDesc(currentUserProvider.getUserId()).stream()
                .map(SleepSessionMapper::toResponse)
                .toList();
    }

    @Override
    @Transactional(readOnly = true)
    public Page<SleepSessionResponse> findDelta(Instant updatedSince, Pageable pageable) {
        // Fixed ordering, tombstones included - see docs/16-delta-sync-rollout.md.
        Pageable deltaPageable = PageRequest.of(
                pageable.getPageNumber(),
                pageable.getPageSize(),
                Sort.by(Sort.Order.asc("updatedAt"), Sort.Order.asc("id")));
        return repository.findByUserIdAndUpdatedAtGreaterThanEqual(currentUserProvider.getUserId(), updatedSince, deltaPageable)
                .map(SleepSessionMapper::toResponse);
    }

    @Override
    public SleepSessionResponse create(SleepSessionRequest request) {
        Long userId = currentUserProvider.getUserId();
        SleepSession session = SleepSessionMapper.toEntity(request);
        // Checked up front so a re-import is a clean 409, which the mobile sync engine reads as "drop the local copy"
        // (the same contract as imported workouts). The unique constraint stays the real guard against a race.
        if (session.getHealthRecordId() != null
                && repository.existsByUserIdAndHealthRecordId(userId, session.getHealthRecordId())) {
            throw new DuplicateResourceException("Sleep session already imported: " + session.getHealthRecordId());
        }
        session.setUser(userRepository.getReferenceById(userId));
        return SleepSessionMapper.toResponse(repository.save(session));
    }

    @Override
    public void delete(Long id) {
        SleepSession session = repository.findByIdAndUserId(id, currentUserProvider.getUserId())
                .orElseThrow(() -> new ResourceNotFoundException("Sleep session not found: " + id));
        session.setDeletedAt(Instant.now());
    }
}

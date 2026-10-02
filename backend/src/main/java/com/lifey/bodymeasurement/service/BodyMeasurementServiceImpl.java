package com.lifey.bodymeasurement.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.bodymeasurement.BodyMeasurement;
import com.lifey.bodymeasurement.BodyMeasurementMapper;
import com.lifey.bodymeasurement.BodyMeasurementRepository;
import com.lifey.bodymeasurement.dto.BodyMeasurementRequest;
import com.lifey.bodymeasurement.dto.BodyMeasurementResponse;
import com.lifey.common.exception.ResourceNotFoundException;
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
public class BodyMeasurementServiceImpl implements BodyMeasurementService {

    private final BodyMeasurementRepository repository;
    private final UserRepository userRepository;
    private final CurrentUserProvider currentUserProvider;

    @Override
    @Transactional(readOnly = true)
    public List<BodyMeasurementResponse> findAll() {
        return repository.findAllByUserIdAndDeletedAtIsNullOrderByDateDescCreatedAtDesc(
                        currentUserProvider.getUserId()).stream()
                .map(BodyMeasurementMapper::toResponse)
                .toList();
    }

    @Override
    @Transactional(readOnly = true)
    public Page<BodyMeasurementResponse> findDelta(Instant updatedSince, Pageable pageable) {
        Pageable deltaPageable = PageRequest.of(
                pageable.getPageNumber(),
                pageable.getPageSize(),
                Sort.by(Sort.Order.asc("updatedAt"), Sort.Order.asc("id")));
        return repository.findByUserIdAndUpdatedAtGreaterThanEqual(
                        currentUserProvider.getUserId(), updatedSince, deltaPageable)
                .map(BodyMeasurementMapper::toResponse);
    }

    @Override
    public BodyMeasurementResponse create(BodyMeasurementRequest request) {
        BodyMeasurement entry = BodyMeasurementMapper.toEntity(request);
        entry.setUser(userRepository.getReferenceById(currentUserProvider.getUserId()));
        return BodyMeasurementMapper.toResponse(repository.save(entry));
    }

    @Override
    public void delete(Long id) {
        BodyMeasurement entry = repository.findByIdAndUserId(id, currentUserProvider.getUserId())
                .orElseThrow(() -> new ResourceNotFoundException("Body measurement not found: " + id));
        entry.setDeletedAt(Instant.now());
    }
}

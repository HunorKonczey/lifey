package com.lifey.water.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.user.UserRepository;
import com.lifey.water.WaterSource;
import com.lifey.water.WaterSourceMapper;
import com.lifey.water.WaterSourceRepository;
import com.lifey.water.dto.WaterSourceRequest;
import com.lifey.water.dto.WaterSourceResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@Transactional
@RequiredArgsConstructor
public class WaterSourceServiceImpl implements WaterSourceService {

    private final WaterSourceRepository repository;
    private final UserRepository userRepository;
    private final CurrentUserProvider currentUserProvider;

    @Override
    @Transactional(readOnly = true)
    public List<WaterSourceResponse> findAll() {
        return repository.findAllByUserId(currentUserProvider.getUserId()).stream()
                .map(WaterSourceMapper::toResponse)
                .toList();
    }

    @Override
    @Transactional(readOnly = true)
    public WaterSourceResponse findById(Long id) {
        return WaterSourceMapper.toResponse(getOrThrow(id));
    }

    @Override
    public WaterSourceResponse create(WaterSourceRequest request) {
        WaterSource source = new WaterSource();
        source.setUser(userRepository.getReferenceById(currentUserProvider.getUserId()));
        WaterSourceMapper.applyRequest(source, request);
        return WaterSourceMapper.toResponse(repository.save(source));
    }

    @Override
    public WaterSourceResponse update(Long id, WaterSourceRequest request) {
        WaterSource source = getOrThrow(id);
        WaterSourceMapper.applyRequest(source, request);
        return WaterSourceMapper.toResponse(source);
    }

    @Override
    public void delete(Long id) {
        Long userId = currentUserProvider.getUserId();
        if (!repository.existsByIdAndUserId(id, userId)) {
            throw new ResourceNotFoundException("Water source not found: " + id);
        }
        repository.deleteByIdAndUserId(id, userId);
    }

    private WaterSource getOrThrow(Long id) {
        return repository.findByIdAndUserId(id, currentUserProvider.getUserId())
                .orElseThrow(() -> new ResourceNotFoundException("Water source not found: " + id));
    }
}

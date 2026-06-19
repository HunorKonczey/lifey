package com.lifey.weight;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.user.UserRepository;
import com.lifey.weight.dto.WeightRequest;
import com.lifey.weight.dto.WeightResponse;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;

@Service
@Transactional
public class WeightServiceImpl implements WeightService {

    private final WeightEntryRepository repository;
    private final UserRepository userRepository;
    private final CurrentUserProvider currentUserProvider;

    public WeightServiceImpl(WeightEntryRepository repository, UserRepository userRepository,
                             CurrentUserProvider currentUserProvider) {
        this.repository = repository;
        this.userRepository = userRepository;
        this.currentUserProvider = currentUserProvider;
    }

    @Override
    @Transactional(readOnly = true)
    public List<WeightResponse> findAll() {
        return repository.findAllByUserIdOrderByDateDescRecordedAtDesc(currentUserProvider.getUserId()).stream()
                .map(WeightMapper::toResponse)
                .toList();
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
        if (!repository.existsByIdAndUserId(id, userId)) {
            throw new ResourceNotFoundException("Weight entry not found: " + id);
        }
        repository.deleteByIdAndUserId(id, userId);
    }
}

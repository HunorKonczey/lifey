package com.lifey.water;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.user.UserRepository;
import com.lifey.water.dto.WaterEntryRequest;
import com.lifey.water.dto.WaterEntryResponse;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

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
        return repository.findAllByUserIdOrderByConsumedAtDesc(currentUserProvider.getUserId()).stream()
                .map(WaterEntryMapper::toResponse)
                .toList();
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
        if (!repository.existsByIdAndUserId(id, userId)) {
            throw new ResourceNotFoundException("Water entry not found: " + id);
        }
        repository.deleteByIdAndUserId(id, userId);
    }
}

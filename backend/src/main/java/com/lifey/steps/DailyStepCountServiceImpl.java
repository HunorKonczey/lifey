package com.lifey.steps;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.steps.dto.DailyStepCountRequest;
import com.lifey.steps.dto.DailyStepCountResponse;
import com.lifey.user.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@Transactional
public class DailyStepCountServiceImpl implements DailyStepCountService {

    private final DailyStepCountRepository repository;
    private final UserRepository userRepository;
    private final CurrentUserProvider currentUserProvider;

    public DailyStepCountServiceImpl(DailyStepCountRepository repository, UserRepository userRepository,
                                     CurrentUserProvider currentUserProvider) {
        this.repository = repository;
        this.userRepository = userRepository;
        this.currentUserProvider = currentUserProvider;
    }

    @Override
    @Transactional(readOnly = true)
    public List<DailyStepCountResponse> findAll() {
        return repository.findAllByUserIdOrderByDateDesc(currentUserProvider.getUserId()).stream()
                .map(DailyStepCountMapper::toResponse)
                .toList();
    }

    @Override
    public DailyStepCountResponse create(DailyStepCountRequest request) {
        Long userId = currentUserProvider.getUserId();
        // Upsert keyed on (user, date): a day's step total is rewritten as steps
        // accumulate, so re-posting the same date updates the row instead of
        // inserting a duplicate (which the unique (user_id, entry_date) index forbids).
        DailyStepCount entry = repository.findByUserIdAndDate(userId, request.date())
                .orElseGet(() -> {
                    DailyStepCount created = DailyStepCountMapper.toEntity(request);
                    created.setUser(userRepository.getReferenceById(userId));
                    return created;
                });
        entry.setSteps(request.steps());
        DailyStepCount saved = repository.save(entry);
        return DailyStepCountMapper.toResponse(saved);
    }

    @Override
    public DailyStepCountResponse update(Long id, DailyStepCountRequest request) {
        Long userId = currentUserProvider.getUserId();
        DailyStepCount entry = repository.findById(id)
                .filter(e -> e.getUser().getId().equals(userId))
                .orElseThrow(() -> new ResourceNotFoundException("Daily step count not found: " + id));
        entry.setDate(request.date());
        entry.setSteps(request.steps());
        DailyStepCount saved = repository.save(entry);
        return DailyStepCountMapper.toResponse(saved);
    }

    @Override
    public void delete(Long id) {
        Long userId = currentUserProvider.getUserId();
        if (!repository.existsByIdAndUserId(id, userId)) {
            throw new ResourceNotFoundException("Daily step count not found: " + id);
        }
        repository.deleteByIdAndUserId(id, userId);
    }
}

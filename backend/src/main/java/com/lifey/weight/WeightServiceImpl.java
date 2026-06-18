package com.lifey.weight;

import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.weight.dto.WeightRequest;
import com.lifey.weight.dto.WeightResponse;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@Transactional
public class WeightServiceImpl implements WeightService {

    private final WeightEntryRepository repository;

    public WeightServiceImpl(WeightEntryRepository repository) {
        this.repository = repository;
    }

    @Override
    @Transactional(readOnly = true)
    public List<WeightResponse> findAll() {
        return repository.findAllByOrderByDateDesc().stream()
                .map(WeightMapper::toResponse)
                .toList();
    }

    @Override
    public WeightResponse create(WeightRequest request) {
        WeightEntry saved = repository.save(WeightMapper.toEntity(request));
        return WeightMapper.toResponse(saved);
    }

    @Override
    public void delete(Long id) {
        if (!repository.existsById(id)) {
            throw new ResourceNotFoundException("Weight entry not found: " + id);
        }
        repository.deleteById(id);
    }
}

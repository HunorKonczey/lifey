package com.lifey.nutrition.food;

import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.nutrition.food.dto.FoodRequest;
import com.lifey.nutrition.food.dto.FoodResponse;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@Transactional
public class FoodServiceImpl implements FoodService {

    private final FoodRepository repository;

    public FoodServiceImpl(FoodRepository repository) {
        this.repository = repository;
    }

    @Override
    @Transactional(readOnly = true)
    public List<FoodResponse> findAll() {
        return repository.findAll().stream()
                .map(FoodMapper::toResponse)
                .toList();
    }

    @Override
    @Transactional(readOnly = true)
    public FoodResponse findById(Long id) {
        return FoodMapper.toResponse(getOrThrow(id));
    }

    @Override
    public FoodResponse create(FoodRequest request) {
        Food saved = repository.save(FoodMapper.toEntity(request));
        return FoodMapper.toResponse(saved);
    }

    @Override
    public FoodResponse update(Long id, FoodRequest request) {
        Food food = getOrThrow(id);
        FoodMapper.apply(food, request);
        return FoodMapper.toResponse(food);
    }

    @Override
    public void delete(Long id) {
        if (!repository.existsById(id)) {
            throw new ResourceNotFoundException("Food not found: " + id);
        }
        repository.deleteById(id);
    }

    private Food getOrThrow(Long id) {
        return repository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Food not found: " + id));
    }
}

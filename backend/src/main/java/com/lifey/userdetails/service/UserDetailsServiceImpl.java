package com.lifey.userdetails.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.user.UserRepository;
import com.lifey.userdetails.GoalCalculator;
import com.lifey.userdetails.UserDetails;
import com.lifey.userdetails.UserDetailsMapper;
import com.lifey.userdetails.UserDetailsRepository;
import com.lifey.userdetails.dto.SuggestGoalsRequest;
import com.lifey.userdetails.dto.SuggestGoalsResponse;
import com.lifey.userdetails.dto.UserDetailsRequest;
import com.lifey.userdetails.dto.UserDetailsResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional
@RequiredArgsConstructor
public class UserDetailsServiceImpl implements UserDetailsService {

    private final UserDetailsRepository repository;
    private final UserRepository userRepository;
    private final CurrentUserProvider currentUserProvider;

    @Override
    @Transactional(readOnly = true)
    public UserDetailsResponse get() {
        Long userId = currentUserProvider.getUserId();
        UserDetails entity = repository.findByUserId(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User has not completed onboarding"));
        return UserDetailsMapper.toResponse(entity);
    }

    @Override
    public UserDetailsResponse upsert(UserDetailsRequest request) {
        Long userId = currentUserProvider.getUserId();
        UserDetails entity = repository.findByUserId(userId).orElseGet(() -> {
            UserDetails created = new UserDetails();
            created.setUser(userRepository.getReferenceById(userId));
            return created;
        });
        UserDetailsMapper.applyRequest(entity, request);
        return UserDetailsMapper.toResponse(repository.save(entity));
    }

    @Override
    @Transactional(readOnly = true)
    public SuggestGoalsResponse suggestGoals(SuggestGoalsRequest request) {
        return GoalCalculator.suggest(request);
    }
}

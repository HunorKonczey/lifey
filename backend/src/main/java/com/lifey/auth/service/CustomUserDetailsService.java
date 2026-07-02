package com.lifey.auth.service;

import com.lifey.auth.UserPrincipal;

import com.lifey.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.jspecify.annotations.NonNull;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class CustomUserDetailsService implements UserDetailsService {

    private final UserRepository userRepository;

    @Override
    @Transactional(readOnly = true)
    public UserDetails loadUserByUsername(@NonNull String email) {
        return userRepository.findByEmailIgnoreCase(email)
                .map(UserPrincipal::from)
                .orElseThrow(() -> new UsernameNotFoundException("No user with email: " + email));
    }
}

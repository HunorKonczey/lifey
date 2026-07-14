package com.lifey.push;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface PushDeviceRepository extends JpaRepository<PushDevice, Long> {

    Optional<PushDevice> findByToken(String token);

    Optional<PushDevice> findByTokenAndUserId(String token, Long userId);

    List<PushDevice> findAllByUserIdAndDeletedAtIsNull(Long userId);
}

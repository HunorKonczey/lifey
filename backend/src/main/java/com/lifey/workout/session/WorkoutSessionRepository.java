package com.lifey.workout.session;

import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.List;

public interface WorkoutSessionRepository extends JpaRepository<WorkoutSession, Long> {

    List<WorkoutSession> findAllByOrderByStartedAtDesc();

    long countByStartedAtGreaterThanEqual(Instant from);
}

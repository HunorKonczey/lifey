package com.lifey.auth;

import com.lifey.user.UserRepository;
import com.lifey.workout.exercise.Exercise;
import com.lifey.workout.exercise.ExerciseRepository;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

import java.util.List;

/**
 * Gives every newly registered user their own starting exercise catalog, now
 * that exercises are user-owned (V40__foods_exercises_ownership.sql) rather
 * than one shared list seeded once by V2__seed_exercises.sql. Runs after the
 * registration transaction commits, in its own transaction, so a failure here
 * never rolls back or blocks account creation — an empty exercise list is a
 * degraded experience, not a broken one.
 */
@Component
@RequiredArgsConstructor
class StarterCatalogListener {

    private static final Logger log = LoggerFactory.getLogger(StarterCatalogListener.class);

    /** Mirrors the original V2__seed_exercises.sql list. */
    private static final List<String> STARTER_EXERCISE_NAMES = List.of(
            "Bench Press",
            "Squat",
            "Deadlift",
            "Overhead Press",
            "Barbell Row",
            "Pull Up",
            "Bicep Curl",
            "Plank"
    );

    private final ExerciseRepository exerciseRepository;
    private final UserRepository userRepository;

    @Transactional
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    void onUserRegistered(UserRegisteredEvent event) {
        try {
            var user = userRepository.getReferenceById(event.userId());
            for (String name : STARTER_EXERCISE_NAMES) {
                Exercise exercise = new Exercise();
                exercise.setUser(user);
                exercise.setName(name);
                exerciseRepository.save(exercise);
            }
        } catch (RuntimeException e) {
            log.error("Failed to seed starter exercise catalog for user {}", event.userId(), e);
        }
    }
}

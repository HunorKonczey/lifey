package com.lifey.workout.session.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.domain.BaseEntity;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.workout.exercise.Exercise;
import com.lifey.workout.exercise.ExerciseRepository;
import com.lifey.workout.session.ExerciseSet;
import com.lifey.workout.session.SessionKind;
import com.lifey.workout.session.WorkoutSession;
import com.lifey.workout.session.WorkoutSessionExercise;
import com.lifey.workout.session.WorkoutSessionRepository;
import com.lifey.workout.session.cardio.ActivityType;
import com.lifey.workout.session.cardio.CardioDetails;
import com.lifey.workout.session.cardio.CardioSplit;
import com.lifey.workout.session.cardio.InvalidCardioRequestException;
import com.lifey.workout.session.dto.CardioDetailsRequest;
import com.lifey.workout.session.dto.CardioSplitRequest;
import com.lifey.workout.session.dto.ExerciseSetRequest;
import com.lifey.workout.session.dto.PlannedExerciseRequest;
import com.lifey.workout.session.dto.ExerciseSummary;
import com.lifey.workout.session.dto.WorkoutSessionRequest;
import com.lifey.workout.session.dto.WorkoutSessionResponse;
import com.lifey.workout.template.WorkoutTemplate;
import com.lifey.workout.template.WorkoutTemplateRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.tuple;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class WorkoutSessionServiceImplTest {

    private static final Long USER_ID = 1L;

    @Mock
    WorkoutSessionRepository sessionRepository;

    @Mock
    ExerciseRepository exerciseRepository;

    @Mock
    UserRepository userRepository;

    @Mock
    WorkoutTemplateRepository templateRepository;

    @Mock
    CurrentUserProvider currentUserProvider;

    @InjectMocks
    WorkoutSessionServiceImpl service;

    @BeforeEach
    void stubCurrentUser() {
        lenient().when(currentUserProvider.getUserId()).thenReturn(USER_ID);
        lenient().when(userRepository.getReferenceById(USER_ID)).thenReturn(new User());
    }

    /**
     * Same shape as the pre-cardio {@code WorkoutSessionRequest} constructor —
     * every existing (STRENGTH) test in this file builds a request this way,
     * leaving the cardio fields (sessionKind, activityType, movingSeconds,
     * cardio, splits) at their "predates cardio" defaults (all null), which
     * is exactly the regression the server must keep handling identically
     * (docs/cardio/52-cardio-domain-backend-plan.md §3.2).
     */
    private static WorkoutSessionRequest strengthRequest(
            Instant startedAt, Instant finishedAt, List<Long> exerciseIds,
            List<ExerciseSetRequest> sets, Double activeCalories, Double averageHeartRate,
            String healthWorkoutId, Long templateId, Integer rpe, String feedbackNote,
            List<PlannedExerciseRequest> plannedExercises) {
        return new WorkoutSessionRequest(startedAt, finishedAt, exerciseIds, sets, activeCalories,
                averageHeartRate, healthWorkoutId, templateId, rpe, feedbackNote, plannedExercises,
                null, null, null, null, null);
    }

    @Test
    void findPage_delegatesToCurrentUser() {
        Pageable requested = PageRequest.of(0, 20);
        WorkoutSession session = new WorkoutSession();
        session.setId(9L);
        session.setStartedAt(Instant.parse("2026-06-18T05:00:00Z"));
        when(sessionRepository.findByUserIdAndDeletedAtIsNullAndStartedAtIsNotNull(USER_ID, requested))
                .thenReturn(new PageImpl<>(List.of(session)));

        Page<WorkoutSessionResponse> result = service.findPage(requested, null);

        assertThat(result.getContent()).singleElement().satisfies(r -> assertThat(r.id()).isEqualTo(9L));
    }

    @Test
    void findPageForUser_scopesToExplicitUser() {
        Pageable requested = PageRequest.of(0, 20);
        WorkoutSession session = new WorkoutSession();
        session.setId(10L);
        session.setStartedAt(Instant.parse("2026-06-18T05:00:00Z"));
        when(sessionRepository.findByUserIdAndDeletedAtIsNullAndStartedAtIsNotNull(99L, requested))
                .thenReturn(new PageImpl<>(List.of(session)));

        Page<WorkoutSessionResponse> result = service.findPageForUser(99L, requested);

        assertThat(result.getContent()).singleElement().satisfies(r -> assertThat(r.id()).isEqualTo(10L));
    }

    @Test
    void create_resolvesPlannedExercisesAndSets() {
        when(exerciseRepository.findByIdAndUserId(1L, USER_ID)).thenReturn(Optional.of(exercise(1L, "Bench Press")));
        when(exerciseRepository.findByIdAndUserId(4L, USER_ID)).thenReturn(Optional.of(exercise(4L, "Overhead Press")));
        when(sessionRepository.save(any(WorkoutSession.class))).thenAnswer(inv -> withId(inv.getArgument(0), 2L));
        Instant started = Instant.parse("2026-06-18T05:00:00Z");
        Instant performedAt = Instant.parse("2026-06-18T05:05:00Z");
        WorkoutSessionRequest request = strengthRequest(started, null,
                List.of(1L, 4L), List.of(new ExerciseSetRequest(1L, 10, 60.0, performedAt)),
                450.0, 132.0, "HK-UUID-1", null, null, null, null);

        WorkoutSessionResponse result = service.create(request);

        assertThat(result.id()).isEqualTo(2L);
        assertThat(result.startedAt()).isEqualTo(started);
        assertThat(result.exercises()).extracting(ExerciseSummary::exerciseId).containsExactly(1L, 4L);
        assertThat(result.sets()).singleElement().satisfies(s -> {
            assertThat(s.exerciseId()).isEqualTo(1L);
            assertThat(s.exerciseName()).isEqualTo("Bench Press");
            assertThat(s.reps()).isEqualTo(10);
            assertThat(s.weight()).isEqualTo(60.0);
            assertThat(s.performedAt()).isEqualTo(performedAt);
        });
        assertThat(result.activeCalories()).isEqualTo(450.0);
        assertThat(result.averageHeartRate()).isEqualTo(132.0);
        assertThat(result.healthWorkoutId()).isEqualTo("HK-UUID-1");
    }

    @Test
    void create_persistsTheTargetSetsEachPlannedExerciseCarries() {
        when(exerciseRepository.findByIdAndUserId(1L, USER_ID)).thenReturn(Optional.of(exercise(1L, "Bench Press")));
        when(exerciseRepository.findByIdAndUserId(4L, USER_ID)).thenReturn(Optional.of(exercise(4L, "Overhead Press")));
        when(sessionRepository.save(any(WorkoutSession.class))).thenAnswer(inv -> withId(inv.getArgument(0), 2L));
        WorkoutSessionRequest request = strengthRequest(
                Instant.parse("2026-06-18T05:00:00Z"), null,
                List.of(1L, 4L), List.of(),
                null, null, null, null, null, null,
                List.of(new PlannedExerciseRequest(1L, 3), new PlannedExerciseRequest(4L, null)));

        WorkoutSessionResponse result = service.create(request);

        // Without this the client's still-blank set rows can't survive a round
        // trip — it rebuilds them as targetSets minus the sets already logged.
        assertThat(result.exercises())
                .extracting(ExerciseSummary::exerciseId, ExerciseSummary::targetSets)
                .containsExactly(tuple(1L, 3), tuple(4L, null));
    }

    @Test
    void create_fallsBackToTheBareExerciseIdsWhenTheClientSendsNoPlan() {
        // The web app and any mobile build older than plannedExercises: still
        // accepted, with "no plan recorded" rather than a rejected request.
        when(exerciseRepository.findByIdAndUserId(1L, USER_ID)).thenReturn(Optional.of(exercise(1L, "Bench Press")));
        when(sessionRepository.save(any(WorkoutSession.class))).thenAnswer(inv -> withId(inv.getArgument(0), 2L));
        WorkoutSessionRequest request = strengthRequest(
                Instant.parse("2026-06-18T05:00:00Z"), null,
                List.of(1L), List.of(),
                null, null, null, null, null, null, null);

        WorkoutSessionResponse result = service.create(request);

        assertThat(result.exercises())
                .extracting(ExerciseSummary::exerciseId, ExerciseSummary::targetSets)
                .containsExactly(tuple(1L, null));
    }

    @Test
    void create_prefersPlannedExercisesOverExerciseIdsWhenBothAreSent() {
        // The mobile client sends both (exerciseIds stays required for older
        // servers), so the structured list has to be the one that wins.
        when(exerciseRepository.findByIdAndUserId(4L, USER_ID)).thenReturn(Optional.of(exercise(4L, "Overhead Press")));
        when(sessionRepository.save(any(WorkoutSession.class))).thenAnswer(inv -> withId(inv.getArgument(0), 2L));
        WorkoutSessionRequest request = strengthRequest(
                Instant.parse("2026-06-18T05:00:00Z"), null,
                List.of(1L), List.of(),
                null, null, null, null, null, null,
                List.of(new PlannedExerciseRequest(4L, 5)));

        WorkoutSessionResponse result = service.create(request);

        assertThat(result.exercises())
                .extracting(ExerciseSummary::exerciseId, ExerciseSummary::targetSets)
                .containsExactly(tuple(4L, 5));
    }

    @Test
    void update_replacesTheStoredTargetSets() {
        WorkoutSession existing = new WorkoutSession();
        existing.setId(3L);
        WorkoutSessionExercise link = new WorkoutSessionExercise();
        link.setWorkoutSession(existing);
        link.setExercise(exercise(1L, "Bench Press"));
        link.setTargetSets(3);
        existing.getPlannedExercises().add(link);
        when(sessionRepository.findByIdAndUserId(3L, USER_ID)).thenReturn(Optional.of(existing));
        when(exerciseRepository.findByIdAndUserId(1L, USER_ID)).thenReturn(Optional.of(exercise(1L, "Bench Press")));
        WorkoutSessionRequest request = strengthRequest(
                Instant.parse("2026-06-18T05:00:00Z"), null,
                List.of(1L), List.of(),
                null, null, null, null, null, null,
                List.of(new PlannedExerciseRequest(1L, 5)));

        WorkoutSessionResponse result = service.update(3L, request);

        // A set added ad hoc mid-workout grows the plan; the next pull has to
        // see 5, not the 3 it started with.
        assertThat(result.exercises())
                .extracting(ExerciseSummary::targetSets)
                .containsExactly(5);
    }

    @Test
    void update_keepsTheStoredTargetSetsWhenTheClientSendsNoPlan() {
        // The web app (and any older mobile build) PUTs bare exerciseIds. That
        // isn't "clear the plan" — it's a client with nothing to say about it,
        // so the count another client recorded has to survive the edit.
        WorkoutSession existing = new WorkoutSession();
        existing.setId(3L);
        WorkoutSessionExercise link = new WorkoutSessionExercise();
        link.setWorkoutSession(existing);
        link.setExercise(exercise(1L, "Bench Press"));
        link.setTargetSets(4);
        existing.getPlannedExercises().add(link);
        when(sessionRepository.findByIdAndUserId(3L, USER_ID)).thenReturn(Optional.of(existing));
        when(exerciseRepository.findByIdAndUserId(1L, USER_ID)).thenReturn(Optional.of(exercise(1L, "Bench Press")));
        WorkoutSessionRequest request = strengthRequest(
                Instant.parse("2026-06-18T05:00:00Z"), null,
                List.of(1L), List.of(),
                null, null, null, null, null, null, null);

        WorkoutSessionResponse result = service.update(3L, request);

        assertThat(result.exercises())
                .extracting(ExerciseSummary::targetSets)
                .containsExactly(4);
    }

    @Test
    void create_allowsAnEmptySessionWithNoPlannedExercisesOrSets() {
        when(sessionRepository.save(any(WorkoutSession.class))).thenAnswer(inv -> withId(inv.getArgument(0), 5L));
        WorkoutSessionRequest request = strengthRequest(
                Instant.parse("2026-06-18T05:00:00Z"), null, List.of(), List.of(),
                null, null, null, null, null, null, null);

        WorkoutSessionResponse result = service.create(request);

        assertThat(result.id()).isEqualTo(5L);
        assertThat(result.exercises()).isEmpty();
        assertThat(result.sets()).isEmpty();
        assertThat(result.activeCalories()).isNull();
        assertThat(result.averageHeartRate()).isNull();
        assertThat(result.healthWorkoutId()).isNull();
    }

    @Test
    void create_dropsIncompleteSetsInsteadOfPersistingThem() {
        when(exerciseRepository.findByIdAndUserId(1L, USER_ID)).thenReturn(Optional.of(exercise(1L, "Bench Press")));
        when(sessionRepository.save(any(WorkoutSession.class))).thenAnswer(inv -> withId(inv.getArgument(0), 9L));
        Instant performedAt = Instant.parse("2026-06-18T05:05:00Z");
        WorkoutSessionRequest request = strengthRequest(
                Instant.parse("2026-06-18T05:00:00Z"), null, List.of(),
                List.of(
                        new ExerciseSetRequest(1L, null, 60.0, performedAt), // reps not filled in yet
                        new ExerciseSetRequest(1L, 0, 60.0, performedAt),    // reps zero
                        new ExerciseSetRequest(1L, 10, null, performedAt),   // weight not filled in yet
                        new ExerciseSetRequest(1L, 10, -5.0, performedAt),   // negative weight
                        new ExerciseSetRequest(1L, 10, 60.0, performedAt)    // the one valid set
                ),
                null, null, null, null, null, null, null);

        WorkoutSessionResponse result = service.create(request);

        assertThat(result.sets()).singleElement().satisfies(s -> {
            assertThat(s.reps()).isEqualTo(10);
            assertThat(s.weight()).isEqualTo(60.0);
        });
    }

    @Test
    void create_throwsWhenPlannedExerciseMissing() {
        when(exerciseRepository.findByIdAndUserId(99L, USER_ID)).thenReturn(Optional.empty());
        WorkoutSessionRequest request = strengthRequest(
                Instant.parse("2026-06-18T05:00:00Z"), null, List.of(99L), List.of(),
                null, null, null, null, null, null, null);

        assertThatThrownBy(() -> service.create(request))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessageContaining("Exercise not found: 99");
    }

    @Test
    void create_throwsWhenSetExerciseMissing() {
        when(exerciseRepository.findByIdAndUserId(99L, USER_ID)).thenReturn(Optional.empty());
        WorkoutSessionRequest request = strengthRequest(
                Instant.parse("2026-06-18T05:00:00Z"), null,
                List.of(), List.of(new ExerciseSetRequest(99L, 5, 100.0,
                Instant.parse("2026-06-18T05:05:00Z"))),
                null, null, null, null, null, null, null);

        assertThatThrownBy(() -> service.create(request))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessageContaining("Exercise not found: 99");
    }

    @Test
    void create_resolvesTemplateAndSnapshotsItsName() {
        when(templateRepository.findByIdAndUserId(7L, USER_ID))
                .thenReturn(Optional.of(template(7L, "Push Day")));
        when(sessionRepository.save(any(WorkoutSession.class))).thenAnswer(inv -> withId(inv.getArgument(0), 6L));
        WorkoutSessionRequest request = strengthRequest(
                Instant.parse("2026-06-18T05:00:00Z"), null, List.of(), List.of(),
                null, null, null, 7L, null, null, null);

        WorkoutSessionResponse result = service.create(request);

        assertThat(result.templateId()).isEqualTo(7L);
        assertThat(result.templateName()).isEqualTo("Push Day");
    }

    @Test
    void create_throwsWhenTemplateMissing() {
        when(templateRepository.findByIdAndUserId(99L, USER_ID)).thenReturn(Optional.empty());
        WorkoutSessionRequest request = strengthRequest(
                Instant.parse("2026-06-18T05:00:00Z"), null, List.of(), List.of(),
                null, null, null, 99L, null, null, null);

        assertThatThrownBy(() -> service.create(request))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessageContaining("Workout template not found: 99");
    }

    @Test
    void update_rebuildsPlannedExercisesAndSetsAndFinishesSession() {
        WorkoutSession existing = new WorkoutSession();
        existing.setId(3L);
        existing.setStartedAt(Instant.parse("2026-06-18T05:00:00Z"));
        WorkoutSessionExercise oldPlanned = new WorkoutSessionExercise();
        oldPlanned.setWorkoutSession(existing);
        oldPlanned.setExercise(exercise(2L, "Squat"));
        existing.getPlannedExercises().add(oldPlanned);
        ExerciseSet oldSet = new ExerciseSet();
        oldSet.setWorkoutSession(existing);
        oldSet.setExercise(exercise(2L, "Squat"));
        oldSet.setReps(5);
        oldSet.setWeight(100.0);
        oldSet.setPerformedAt(Instant.parse("2026-06-18T05:00:00Z"));
        existing.getSets().add(oldSet);

        when(sessionRepository.findByIdAndUserId(3L, USER_ID)).thenReturn(Optional.of(existing));
        when(exerciseRepository.findByIdAndUserId(1L, USER_ID)).thenReturn(Optional.of(exercise(1L, "Bench Press")));
        Instant finished = Instant.parse("2026-06-18T06:00:00Z");
        WorkoutSessionRequest request = strengthRequest(
                Instant.parse("2026-06-18T05:00:00Z"), finished,
                List.of(1L), List.of(new ExerciseSetRequest(1L, 8, 70.0,
                Instant.parse("2026-06-18T05:30:00Z"))),
                480.0, 140.0, "HK-UUID-2", null, null, null, null);

        WorkoutSessionResponse result = service.update(3L, request);

        assertThat(result.finishedAt()).isEqualTo(finished);
        assertThat(result.exercises()).singleElement().satisfies(e -> assertThat(e.exerciseId()).isEqualTo(1L));
        assertThat(result.sets()).singleElement().satisfies(s -> assertThat(s.reps()).isEqualTo(8));
        assertThat(existing.getPlannedExercises()).hasSize(1);
        assertThat(existing.getSets()).hasSize(1);
        assertThat(result.activeCalories()).isEqualTo(480.0);
        assertThat(result.averageHeartRate()).isEqualTo(140.0);
        assertThat(result.healthWorkoutId()).isEqualTo("HK-UUID-2");
    }

    @Test
    void update_throwsWhenMissing() {
        when(sessionRepository.findByIdAndUserId(99L, USER_ID)).thenReturn(Optional.empty());
        WorkoutSessionRequest request = strengthRequest(
                Instant.parse("2026-06-18T05:00:00Z"), null,
                List.of(), List.of(new ExerciseSetRequest(1L, 5, 50.0,
                Instant.parse("2026-06-18T05:05:00Z"))),
                null, null, null, null, null, null, null);

        assertThatThrownBy(() -> service.update(99L, request))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void delete_throwsWhenMissing() {
        when(sessionRepository.findByIdAndUserId(99L, USER_ID)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.delete(99L))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void delete_setsDeletedAtInsteadOfRemovingRow() {
        WorkoutSession existing = new WorkoutSession();
        existing.setId(3L);
        when(sessionRepository.findByIdAndUserId(3L, USER_ID)).thenReturn(Optional.of(existing));

        service.delete(3L);

        assertThat(existing.getDeletedAt()).isNotNull();
    }

    @Test
    void update_childOnlyEditBumpsParentUpdatedAt() {
        WorkoutSession existing = new WorkoutSession();
        existing.setId(3L);
        existing.setStartedAt(Instant.parse("2026-06-18T05:00:00Z"));
        existing.setUpdatedAt(Instant.parse("2026-06-18T05:00:00Z"));
        when(sessionRepository.findByIdAndUserId(3L, USER_ID)).thenReturn(Optional.of(existing));
        when(exerciseRepository.findByIdAndUserId(1L, USER_ID)).thenReturn(Optional.of(exercise(1L, "Bench Press")));

        // Same startedAt/finishedAt/etc as before — only the sets differ.
        WorkoutSessionRequest request = strengthRequest(
                Instant.parse("2026-06-18T05:00:00Z"), null,
                List.of(), List.of(new ExerciseSetRequest(1L, 8, 70.0,
                Instant.parse("2026-06-18T05:30:00Z"))),
                null, null, null, null, null, null, null);

        service.update(3L, request);

        assertThat(existing.getUpdatedAt()).isAfter(Instant.parse("2026-06-18T05:00:00Z"));
    }

    @Test
    void update_leavesTrainerCommentUntouched() {
        // Pins the session-feedback-loop invariant (docs/31, B1): the trainer
        // comment is trainer-owned — the client-facing update path must never
        // touch it, so an offline client edit pushed later can't clobber a
        // comment written in the meantime.
        WorkoutSession existing = new WorkoutSession();
        existing.setId(3L);
        existing.setStartedAt(Instant.parse("2026-06-18T05:00:00Z"));
        existing.setTrainerComment("Nice pace, add weight next time");
        existing.setTrainerCommentAt(Instant.parse("2026-06-18T07:00:00Z"));
        existing.setTrainerCommentBy(42L);
        when(sessionRepository.findByIdAndUserId(3L, USER_ID)).thenReturn(Optional.of(existing));

        WorkoutSessionRequest request = strengthRequest(
                Instant.parse("2026-06-18T05:00:00Z"), Instant.parse("2026-06-18T06:00:00Z"),
                List.of(), List.of(), null, null, null, null, 8, "felt strong", null);

        WorkoutSessionResponse result = service.update(3L, request);

        assertThat(existing.getTrainerComment()).isEqualTo("Nice pace, add weight next time");
        assertThat(existing.getTrainerCommentAt()).isEqualTo(Instant.parse("2026-06-18T07:00:00Z"));
        assertThat(existing.getTrainerCommentBy()).isEqualTo(42L);
        assertThat(result.trainerComment()).isEqualTo("Nice pace, add weight next time");
        assertThat(result.trainerCommentAt()).isEqualTo(Instant.parse("2026-06-18T07:00:00Z"));
    }

    // -- Cardio (docs/cardio/52-cardio-domain-backend-plan.md §3.2, C1.4) ----

    /**
     * Field order mirrors {@link CardioDetailsRequest} exactly — see its
     * doc for the grouping (DISTANCE+MACHINE / MACHINE / physiological /
     * GAME / provenance / route). Only distanceMeters and intensity are
     * parameterized; everything else is null.
     */
    private static CardioDetailsRequest cardioDetails(Double distanceMeters, Integer intensity) {
        return new CardioDetailsRequest(
                distanceMeters,
                null, null, null, null, null, null,   // elevationGain..maxCadence
                null, null, null, null,                // avgWatts..deviceCalories
                null, null, null, null, null, null,    // maxHeartRate..hrZone5Seconds
                intensity,
                null, null, null, null, null, null, null, null, null); // venue..routePointCount
    }

    @Test
    void create_cardioSession_persistsActivityTypeMovingSecondsCardioDetailsAndSplits() {
        when(sessionRepository.save(any(WorkoutSession.class))).thenAnswer(inv -> withId(inv.getArgument(0), 7L));
        Instant started = Instant.parse("2026-06-18T05:00:00Z");
        WorkoutSessionRequest request = new WorkoutSessionRequest(started, null, List.of(), List.of(),
                null, null, null, null, null, null, null,
                SessionKind.CARDIO, ActivityType.RUNNING, 1800,
                cardioDetails(5230.0, 4),
                List.of(new CardioSplitRequest(0, 1000.0, 320, -2.5, 151.0)));

        WorkoutSessionResponse result = service.create(request);

        assertThat(result.sessionKind()).isEqualTo(SessionKind.CARDIO);
        assertThat(result.activityType()).isEqualTo(ActivityType.RUNNING);
        assertThat(result.movingSeconds()).isEqualTo(1800);
        assertThat(result.cardio()).isNotNull();
        assertThat(result.cardio().distanceMeters()).isEqualTo(5230.0);
        assertThat(result.cardio().intensity()).isEqualTo(4);
        assertThat(result.splits()).singleElement().satisfies(s -> {
            assertThat(s.splitIndex()).isEqualTo(0);
            assertThat(s.distanceMeters()).isEqualTo(1000.0);
            assertThat(s.durationSeconds()).isEqualTo(320);
        });
        // Empty, never null — a cardio session has no exercises/sets (docs/cardio/52 §3.3).
        assertThat(result.exercises()).isEmpty();
        assertThat(result.sets()).isEmpty();
    }

    @Test
    void create_omittedSessionKind_defaultsToStrengthInResponse() {
        // The regression the whole discriminator design exists to avoid: a
        // client that predates cardio sends no sessionKind at all.
        when(sessionRepository.save(any(WorkoutSession.class))).thenAnswer(inv -> withId(inv.getArgument(0), 8L));
        WorkoutSessionRequest request = strengthRequest(
                Instant.parse("2026-06-18T05:00:00Z"), null, List.of(), List.of(),
                null, null, null, null, null, null, null);

        WorkoutSessionResponse result = service.create(request);

        assertThat(result.sessionKind()).isEqualTo(SessionKind.STRENGTH);
        assertThat(result.activityType()).isNull();
        assertThat(result.cardio()).isNull();
        assertThat(result.splits()).isEmpty();
    }

    @Test
    void create_cardioWithoutActivityType_throwsInvalidCardioRequestException() {
        WorkoutSessionRequest request = new WorkoutSessionRequest(
                Instant.parse("2026-06-18T05:00:00Z"), null, List.of(), List.of(),
                null, null, null, null, null, null, null,
                SessionKind.CARDIO, null, null, null, null);

        assertThatThrownBy(() -> service.create(request))
                .isInstanceOf(InvalidCardioRequestException.class);
    }

    @Test
    void create_strengthWithActivityType_throwsInvalidCardioRequestException() {
        WorkoutSessionRequest request = new WorkoutSessionRequest(
                Instant.parse("2026-06-18T05:00:00Z"), null, List.of(), List.of(),
                null, null, null, null, null, null, null,
                null, ActivityType.RUNNING, null, null, null);

        assertThatThrownBy(() -> service.create(request))
                .isInstanceOf(InvalidCardioRequestException.class);
    }

    @Test
    void create_strengthWithCardioBlock_throwsInvalidCardioRequestException() {
        WorkoutSessionRequest request = new WorkoutSessionRequest(
                Instant.parse("2026-06-18T05:00:00Z"), null, List.of(), List.of(),
                null, null, null, null, null, null, null,
                null, null, null, cardioDetails(1000.0, null), null);

        assertThatThrownBy(() -> service.create(request))
                .isInstanceOf(InvalidCardioRequestException.class);
    }

    @Test
    void create_strengthWithNonEmptySplits_throwsInvalidCardioRequestException() {
        WorkoutSessionRequest request = new WorkoutSessionRequest(
                Instant.parse("2026-06-18T05:00:00Z"), null, List.of(), List.of(),
                null, null, null, null, null, null, null,
                null, null, null, null, List.of(new CardioSplitRequest(0, 1000.0, 300, null, null)));

        assertThatThrownBy(() -> service.create(request))
                .isInstanceOf(InvalidCardioRequestException.class);
    }

    @Test
    void update_cardioOnlyEditBumpsParentUpdatedAt() {
        // The exact cardio counterpart of update_childOnlyEditBumpsParentUpdatedAt
        // — the highest-risk regression in the whole cardio rollout
        // (docs/cardio/52 §4): a cardio-only edit must still bump updatedAt,
        // or the change never reaches the delta-sync feed.
        WorkoutSession existing = new WorkoutSession();
        existing.setId(3L);
        existing.setStartedAt(Instant.parse("2026-06-18T05:00:00Z"));
        existing.setUpdatedAt(Instant.parse("2026-06-18T05:00:00Z"));
        existing.setSessionKind(SessionKind.CARDIO);
        existing.setActivityType(ActivityType.RUNNING);
        when(sessionRepository.findByIdAndUserId(3L, USER_ID)).thenReturn(Optional.of(existing));

        // Same startedAt/finishedAt/activityType as before — only cardio.distanceMeters differs.
        WorkoutSessionRequest request = new WorkoutSessionRequest(
                Instant.parse("2026-06-18T05:00:00Z"), null, List.of(), List.of(),
                null, null, null, null, null, null, null,
                SessionKind.CARDIO, ActivityType.RUNNING, null,
                cardioDetails(6100.0, null), null);

        service.update(3L, request);

        assertThat(existing.getUpdatedAt()).isAfter(Instant.parse("2026-06-18T05:00:00Z"));
        assertThat(existing.getCardioDetails().getDistanceMeters()).isEqualTo(6100.0);
    }

    @Test
    void update_reusesTheExistingCardioDetailsRowRatherThanADuplicate() {
        WorkoutSession existing = new WorkoutSession();
        existing.setId(3L);
        existing.setStartedAt(Instant.parse("2026-06-18T05:00:00Z"));
        existing.setSessionKind(SessionKind.CARDIO);
        existing.setActivityType(ActivityType.RUNNING);
        CardioDetails priorDetails = new CardioDetails();
        priorDetails.setWorkoutSession(existing);
        priorDetails.setDistanceMeters(4000.0);
        existing.setCardioDetails(priorDetails);
        when(sessionRepository.findByIdAndUserId(3L, USER_ID)).thenReturn(Optional.of(existing));

        WorkoutSessionRequest request = new WorkoutSessionRequest(
                Instant.parse("2026-06-18T05:00:00Z"), null, List.of(), List.of(),
                null, null, null, null, null, null, null,
                SessionKind.CARDIO, ActivityType.RUNNING, null,
                cardioDetails(4200.0, null), null);

        service.update(3L, request);

        assertThat(existing.getCardioDetails()).isSameAs(priorDetails);
        assertThat(existing.getCardioDetails().getDistanceMeters()).isEqualTo(4200.0);
    }

    @Test
    void update_nullCardioBlockClearsAnExistingCardioDetailsRow() {
        // Full-replace semantics, same model as sets/plannedExercises: the
        // client always sends its complete current cardio state, so a null
        // cardio block means "no cardio data", not "leave it as-is".
        WorkoutSession existing = new WorkoutSession();
        existing.setId(3L);
        existing.setStartedAt(Instant.parse("2026-06-18T05:00:00Z"));
        existing.setSessionKind(SessionKind.CARDIO);
        existing.setActivityType(ActivityType.RUNNING);
        CardioDetails priorDetails = new CardioDetails();
        priorDetails.setWorkoutSession(existing);
        priorDetails.setDistanceMeters(4000.0);
        existing.setCardioDetails(priorDetails);
        when(sessionRepository.findByIdAndUserId(3L, USER_ID)).thenReturn(Optional.of(existing));

        WorkoutSessionRequest request = new WorkoutSessionRequest(
                Instant.parse("2026-06-18T05:00:00Z"), null, List.of(), List.of(),
                null, null, null, null, null, null, null,
                SessionKind.CARDIO, ActivityType.RUNNING, null, null, null);

        service.update(3L, request);

        assertThat(existing.getCardioDetails()).isNull();
    }

    @Test
    void update_splitsListIsFullyReplaced() {
        WorkoutSession existing = new WorkoutSession();
        existing.setId(3L);
        existing.setStartedAt(Instant.parse("2026-06-18T05:00:00Z"));
        existing.setSessionKind(SessionKind.CARDIO);
        existing.setActivityType(ActivityType.RUNNING);
        CardioSplit oldSplit = new CardioSplit();
        oldSplit.setWorkoutSession(existing);
        oldSplit.setSplitIndex(0);
        oldSplit.setDistanceMeters(999.0);
        oldSplit.setDurationSeconds(300);
        existing.getSplits().add(oldSplit);
        when(sessionRepository.findByIdAndUserId(3L, USER_ID)).thenReturn(Optional.of(existing));

        WorkoutSessionRequest request = new WorkoutSessionRequest(
                Instant.parse("2026-06-18T05:00:00Z"), null, List.of(), List.of(),
                null, null, null, null, null, null, null,
                SessionKind.CARDIO, ActivityType.RUNNING, null, null,
                List.of(new CardioSplitRequest(0, 1000.0, 310, null, null),
                        new CardioSplitRequest(1, 1000.0, 315, null, null)));

        service.update(3L, request);

        assertThat(existing.getSplits()).hasSize(2);
        assertThat(existing.getSplits()).extracting(CardioSplit::getDistanceMeters)
                .containsExactly(1000.0, 1000.0);
    }

    @Test
    void findDelta_isUserScopedAndIncludesTombstones() {
        WorkoutSession deleted = new WorkoutSession();
        deleted.setId(2L);
        deleted.setDeletedAt(Instant.parse("2026-06-19T00:00:00Z"));

        Instant since = Instant.parse("2026-06-17T00:00:00Z");
        Pageable requested = PageRequest.of(0, 50);
        Page<WorkoutSession> page = new PageImpl<>(List.of(deleted));
        when(sessionRepository.findByUserIdAndUpdatedAtGreaterThanEqual(eq(USER_ID), eq(since), any()))
                .thenReturn(page);

        Page<WorkoutSessionResponse> result = service.findDelta(since, requested);

        assertThat(result.getContent()).singleElement().satisfies(r -> {
            assertThat(r.id()).isEqualTo(2L);
            assertThat(r.deletedAt()).isEqualTo(deleted.getDeletedAt());
        });
    }

    private static Exercise exercise(Long id, String name) {
        Exercise e = new Exercise();
        e.setId(id);
        e.setName(name);
        return e;
    }

    private static WorkoutTemplate template(Long id, String name) {
        WorkoutTemplate t = new WorkoutTemplate();
        t.setId(id);
        t.setName(name);
        return t;
    }

    private static <T extends BaseEntity> T withId(T entity, Long id) {
        entity.setId(id);
        return entity;
    }
}

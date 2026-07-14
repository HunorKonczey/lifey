package com.lifey.trainer.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.DuplicateResourceException;
import com.lifey.push.service.PushMessage;
import com.lifey.push.service.PushService;
import com.lifey.settings.LanguagePreference;
import com.lifey.settings.UserSettings;
import com.lifey.settings.UserSettingsRepository;
import com.lifey.trainer.ProgramAssignmentRepository;
import com.lifey.trainer.TrainingProgramRepository;
import com.lifey.trainer.dto.ProgramAssignmentRequest;
import com.lifey.trainer.dto.ProgramAssignmentResponse;
import com.lifey.trainer.dto.ProgramAssignmentSummaryResponse;
import com.lifey.trainer.entity.ProgramAssignment;
import com.lifey.trainer.entity.ProgramWorkout;
import com.lifey.trainer.entity.TrainingProgram;
import com.lifey.trainer.exception.InvalidProgramStructureException;
import com.lifey.trainer.exception.ProgramAssignmentNotFoundException;
import com.lifey.trainer.exception.ProgramNotFoundException;
import com.lifey.trainer.exception.ProgramStartDateInvalidException;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import com.lifey.workout.session.WorkoutSession;
import com.lifey.workout.session.WorkoutSessionRepository;
import com.lifey.workout.template.WorkoutTemplate;
import com.lifey.workout.template.WorkoutTemplateRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;

/**
 * Assignment/occurrence generation for multi-week programs
 * (docs/34-multi-week-program-plan.md). Occurrences are plain
 * {@code workout_sessions} rows carrying {@code programAssignmentId} —
 * mirrors {@link WorkoutScheduleServiceImpl}'s schedule-materialization flow.
 */
@Service
@RequiredArgsConstructor
@Transactional
public class ProgramAssignmentServiceImpl implements ProgramAssignmentService {

    private final ProgramAssignmentRepository programAssignmentRepository;
    private final TrainingProgramRepository trainingProgramRepository;
    private final WorkoutTemplateRepository workoutTemplateRepository;
    private final WorkoutSessionRepository workoutSessionRepository;
    private final ContentAssignmentService contentAssignmentService;
    private final TrainerAccessService trainerAccessService;
    private final UserRepository userRepository;
    private final UserSettingsRepository userSettingsRepository;
    private final PushService pushService;
    private final CurrentUserProvider currentUserProvider;

    @Override
    public ProgramAssignmentResponse assign(Long programId, ProgramAssignmentRequest request) {
        Long trainerId = currentUserProvider.getUserId();
        trainerAccessService.requireActiveClient(trainerId, request.clientId());

        TrainingProgram program = trainingProgramRepository.findByIdAndUserIdAndDeletedAtIsNull(programId, trainerId)
                .orElseThrow(() -> new ProgramNotFoundException("Program not found: " + programId));
        if (program.getWorkouts().isEmpty()) {
            throw new InvalidProgramStructureException("Program has no workouts to assign: " + programId);
        }

        if (!DayOfWeek.MONDAY.equals(request.startDate().getDayOfWeek())) {
            throw new ProgramStartDateInvalidException("Program start date must be a Monday");
        }
        if (request.startDate().isBefore(LocalDate.now())) {
            throw new ProgramStartDateInvalidException("Program start date cannot be in the past");
        }
        if (programAssignmentRepository.existsByProgramIdAndClientIdAndCancelledAtIsNullAndEndDateGreaterThanEqual(
                programId, request.clientId(), LocalDate.now())) {
            throw new DuplicateResourceException("This client already has an active run of this program");
        }

        LocalDate endDate = request.startDate().plusWeeks(program.getWeeksCount()).minusDays(1);
        Map<Long, WorkoutTemplate> clientTemplatesById = resolveClientTemplates(trainerId, request.clientId(), program);

        ProgramAssignment assignment = new ProgramAssignment();
        assignment.setProgram(program);
        assignment.setTrainer(userRepository.getReferenceById(trainerId));
        assignment.setClient(userRepository.getReferenceById(request.clientId()));
        assignment.setProgramName(program.getName());
        assignment.setStartDate(request.startDate());
        assignment.setEndDate(endDate);
        assignment.setAssignedAt(Instant.now());
        ProgramAssignment saved = programAssignmentRepository.save(assignment);

        User client = userRepository.getReferenceById(request.clientId());
        for (ProgramWorkout slot : program.getWorkouts()) {
            materializeOccurrence(saved, slot, client, clientTemplatesById.get(slot.getTemplate().getId()));
        }

        sendAssignedPush(saved, program);

        return new ProgramAssignmentResponse(
                saved.getId(), program.getName(), request.startDate(), endDate, program.getWorkouts().size());
    }

    /**
     * "Your trainer started you on {program}" push (docs/34-multi-week-program-plan.md,
     * M6) — same opt-out/localization shape as {@code SessionCommentServiceImpl}
     * and {@code ClientNutritionGoalsServiceImpl}.
     */
    private void sendAssignedPush(ProgramAssignment assignment, TrainingProgram program) {
        Long clientId = assignment.getClient().getId();
        Optional<UserSettings> settings = userSettingsRepository.findByUserId(clientId);
        if (!settings.map(UserSettings::isProgramAssignedPushEnabled).orElse(true)) {
            return;
        }
        boolean hungarian = settings.map(s -> s.getLanguage() == LanguagePreference.HUNGARIAN).orElse(false);
        pushService.sendToUser(clientId, buildAssignedMessage(assignment, program, hungarian));
    }

    private static PushMessage buildAssignedMessage(ProgramAssignment assignment, TrainingProgram program, boolean hungarian) {
        LocalDate firstOccurrence = firstOccurrenceDate(assignment, program);
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern(
                "EEE, MMM d", hungarian ? Locale.forLanguageTag("hu") : Locale.ENGLISH);
        String dateLabel = firstOccurrence.format(formatter);

        String title = hungarian
                ? "Az edződ elindított egy programot"
                : "Your trainer started you on a program";
        String body = hungarian
                ? assignment.getProgramName() + " — első edzés: " + dateLabel
                : assignment.getProgramName() + ", first session " + dateLabel;
        Map<String, String> data = Map.of(
                "type", "program_assigned",
                "programAssignmentId", String.valueOf(assignment.getId())
        );
        return new PushMessage(title, body, data);
    }

    /** Earliest occurrence in the grid by (weekNumber, dayOfWeek) — not necessarily the assignment's own startDate, since week 1's first slot may not fall on the Monday itself. */
    private static LocalDate firstOccurrenceDate(ProgramAssignment assignment, TrainingProgram program) {
        ProgramWorkout earliest = program.getWorkouts().stream()
                .min(Comparator.comparingInt(ProgramWorkout::getWeekNumber)
                        .thenComparing(w -> OccurrenceGenerator.fromCode(w.getDayOfWeek())))
                .orElseThrow();
        int dayOffset = OccurrenceGenerator.fromCode(earliest.getDayOfWeek()).getValue() - DayOfWeek.MONDAY.getValue();
        return assignment.getStartDate().plusWeeks(earliest.getWeekNumber() - 1L).plusDays(dayOffset);
    }

    /**
     * Resolves each distinct slot template to the client's copy, validating the
     * trainer's template is still live — a template deleted after the program
     * was built fails the whole assignment atomically, naming the offending id.
     */
    private Map<Long, WorkoutTemplate> resolveClientTemplates(Long trainerId, Long clientId, TrainingProgram program) {
        Map<Long, WorkoutTemplate> clientTemplatesById = new HashMap<>();
        for (ProgramWorkout slot : program.getWorkouts()) {
            Long templateId = slot.getTemplate().getId();
            clientTemplatesById.computeIfAbsent(templateId, id -> {
                WorkoutTemplate current = workoutTemplateRepository.findByIdAndUserIdAndDeletedAtIsNull(id, trainerId)
                        .orElseThrow(() -> new InvalidProgramStructureException("Workout template not found: " + id));
                return contentAssignmentService.resolveClientCopy(trainerId, clientId, current);
            });
        }
        return clientTemplatesById;
    }

    private void materializeOccurrence(ProgramAssignment assignment, ProgramWorkout slot, User client, WorkoutTemplate clientTemplate) {
        int dayOffset = OccurrenceGenerator.fromCode(slot.getDayOfWeek()).getValue() - DayOfWeek.MONDAY.getValue();
        LocalDate occurrenceDate = assignment.getStartDate().plusWeeks(slot.getWeekNumber() - 1L).plusDays(dayOffset);

        WorkoutSession occurrence = new WorkoutSession();
        occurrence.setUser(client);
        occurrence.setScheduledFor(occurrenceDate);
        occurrence.setScheduledTime(slot.getTimeOfDay());
        occurrence.setProgramAssignmentId(assignment.getId());
        occurrence.setTemplate(clientTemplate);
        occurrence.setTemplateName(clientTemplate.getName());
        workoutSessionRepository.save(occurrence);
    }

    @Override
    @Transactional(readOnly = true)
    public List<ProgramAssignmentSummaryResponse> findForClient(Long clientId) {
        Long trainerId = currentUserProvider.getUserId();
        trainerAccessService.requireActiveClient(trainerId, clientId);

        return programAssignmentRepository.findByTrainerIdAndClientIdOrderByStartDateDesc(trainerId, clientId).stream()
                .map(this::toSummary)
                .toList();
    }

    private ProgramAssignmentSummaryResponse toSummary(ProgramAssignment assignment) {
        LocalDate today = LocalDate.now();
        long done = workoutSessionRepository.countByProgramAssignmentIdAndStartedAtIsNotNull(assignment.getId());
        long missed = workoutSessionRepository.countByProgramAssignmentIdAndStartedAtIsNullAndDeletedAtIsNullAndScheduledForBefore(
                assignment.getId(), today);
        long remaining = workoutSessionRepository.countByProgramAssignmentIdAndStartedAtIsNullAndDeletedAtIsNullAndScheduledForGreaterThanEqual(
                assignment.getId(), today);

        return new ProgramAssignmentSummaryResponse(
                assignment.getId(), assignment.getClient().getId(), assignment.getProgram().getId(),
                assignment.getProgramName(), assignment.getStartDate(), assignment.getEndDate(),
                (int) done, (int) missed, (int) remaining, assignment.getCancelledAt());
    }

    @Override
    public void cancel(Long assignmentId) {
        Long trainerId = currentUserProvider.getUserId();
        ProgramAssignment assignment = programAssignmentRepository.findByIdAndTrainerId(assignmentId, trainerId)
                .orElseThrow(() -> new ProgramAssignmentNotFoundException("Program assignment not found: " + assignmentId));
        cancel(assignment);
    }

    private void cancel(ProgramAssignment assignment) {
        assignment.setCancelledAt(Instant.now());
        Instant now = Instant.now();
        for (WorkoutSession occurrence : workoutSessionRepository
                .findByProgramAssignmentIdAndStartedAtIsNullAndDeletedAtIsNullAndScheduledForGreaterThanEqual(
                        assignment.getId(), LocalDate.now())) {
            occurrence.setDeletedAt(now);
        }
    }

    @Override
    public void cancelActiveAssignmentsForPair(Long trainerId, Long clientId) {
        for (ProgramAssignment assignment : programAssignmentRepository
                .findByTrainerIdAndClientIdAndCancelledAtIsNull(trainerId, clientId)) {
            cancel(assignment);
        }
    }
}

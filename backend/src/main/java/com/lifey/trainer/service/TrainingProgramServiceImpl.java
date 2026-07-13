package com.lifey.trainer.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.trainer.ProgramAssignmentRepository;
import com.lifey.trainer.TrainingProgramRepository;
import com.lifey.trainer.dto.ProgramRequest;
import com.lifey.trainer.dto.ProgramResponse;
import com.lifey.trainer.dto.ProgramSummaryResponse;
import com.lifey.trainer.dto.ProgramWorkoutRequest;
import com.lifey.trainer.dto.ProgramWorkoutResponse;
import com.lifey.trainer.entity.ProgramWorkout;
import com.lifey.trainer.entity.TrainingProgram;
import com.lifey.trainer.exception.InvalidProgramStructureException;
import com.lifey.trainer.exception.ProgramNotFoundException;
import com.lifey.user.UserRepository;
import com.lifey.workout.template.WorkoutTemplate;
import com.lifey.workout.template.WorkoutTemplateRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Program CRUD (docs/34-multi-week-program-plan.md). Assignment/occurrence
 * generation lives in {@code ProgramAssignmentService} — this service only
 * manages the reusable blueprint.
 */
@Service
@RequiredArgsConstructor
@Transactional
public class TrainingProgramServiceImpl implements TrainingProgramService {

    private final TrainingProgramRepository trainingProgramRepository;
    private final ProgramAssignmentRepository programAssignmentRepository;
    private final WorkoutTemplateRepository workoutTemplateRepository;
    private final UserRepository userRepository;
    private final CurrentUserProvider currentUserProvider;

    @Override
    public ProgramResponse create(ProgramRequest request) {
        Long trainerId = currentUserProvider.getUserId();

        Map<Long, WorkoutTemplate> templatesById = resolveTemplates(trainerId, request.workouts());
        validateStructure(request.weeksCount(), request.workouts());

        TrainingProgram program = new TrainingProgram();
        program.setUser(userRepository.getReferenceById(trainerId));
        Instant now = Instant.now();
        program.setCreatedAt(now);
        applyRequest(program, request, templatesById, now);

        return toResponse(trainingProgramRepository.save(program));
    }

    @Override
    @Transactional(readOnly = true)
    public List<ProgramSummaryResponse> findAll() {
        Long trainerId = currentUserProvider.getUserId();
        LocalDate today = LocalDate.now();

        return trainingProgramRepository.findByUserIdAndDeletedAtIsNullOrderByCreatedAtDesc(trainerId).stream()
                .map(program -> toSummary(program, today))
                .toList();
    }

    private ProgramSummaryResponse toSummary(TrainingProgram program, LocalDate today) {
        int slotsPerWeek = (int) program.getWorkouts().stream().map(ProgramWorkout::getDayOfWeek).distinct().count();
        int activeAssignmentCount = programAssignmentRepository
                .countByProgramIdAndCancelledAtIsNullAndEndDateGreaterThanEqual(program.getId(), today);
        return new ProgramSummaryResponse(program.getId(), program.getName(), program.getWeeksCount(),
                slotsPerWeek, activeAssignmentCount);
    }

    @Override
    @Transactional(readOnly = true)
    public ProgramResponse findById(Long programId) {
        return toResponse(getOwnedProgram(programId));
    }

    @Override
    public ProgramResponse update(Long programId, ProgramRequest request) {
        Long trainerId = currentUserProvider.getUserId();
        TrainingProgram program = getOwnedProgram(programId);

        Map<Long, WorkoutTemplate> templatesById = resolveTemplates(trainerId, request.workouts());
        validateStructure(request.weeksCount(), request.workouts());

        // Clear + flush before re-adding: Hibernate's default flush order runs entity
        // insertions before deletions, so without an explicit flush here, a re-saved
        // slot at the same (week, day) as before would try to INSERT its new row while
        // the old one (now an orphan, but not yet DELETEd) still occupies that unique
        // (program_id, week_number, day_of_week) key — a spurious constraint violation.
        program.getWorkouts().clear();
        trainingProgramRepository.flush();

        applyRequest(program, request, templatesById, Instant.now());
        return toResponse(program);
    }

    @Override
    public void delete(Long programId) {
        TrainingProgram program = getOwnedProgram(programId);
        program.setDeletedAt(Instant.now());
    }

    private TrainingProgram getOwnedProgram(Long programId) {
        Long trainerId = currentUserProvider.getUserId();
        return trainingProgramRepository.findByIdAndUserIdAndDeletedAtIsNull(programId, trainerId)
                .orElseThrow(() -> new ProgramNotFoundException("Program not found: " + programId));
    }

    /**
     * Full replace of name/weeks/slots — mirrors the full-overwrite pattern
     * used by {@code ContentAssignmentServiceImpl#copyTemplateFields}. Relies
     * on {@code orphanRemoval} on {@link TrainingProgram#getWorkouts()} to
     * drop slots that aren't re-added.
     */
    private void applyRequest(TrainingProgram program, ProgramRequest request,
            Map<Long, WorkoutTemplate> templatesById, Instant now) {
        program.setName(request.name());
        program.setWeeksCount(request.weeksCount());
        program.getWorkouts().clear();
        for (ProgramWorkoutRequest slot : request.workouts()) {
            ProgramWorkout workout = new ProgramWorkout();
            workout.setProgram(program);
            workout.setWeekNumber(slot.weekNumber());
            workout.setDayOfWeek(OccurrenceGenerator.toCode(slot.dayOfWeek()));
            workout.setTemplate(templatesById.get(slot.templateId()));
            workout.setTimeOfDay(slot.timeOfDay());
            workout.setNote(slot.note());
            program.getWorkouts().add(workout);
        }
        program.setUpdatedAt(now);
    }

    /**
     * @throws InvalidProgramStructureException if a slot's week number exceeds
     *                                           {@code weeksCount}, or two slots share the same (week, day)
     */
    private void validateStructure(int weeksCount, List<ProgramWorkoutRequest> workouts) {
        Set<String> seenSlots = new HashSet<>();
        for (ProgramWorkoutRequest slot : workouts) {
            if (slot.weekNumber() > weeksCount) {
                throw new InvalidProgramStructureException(
                        "Slot week " + slot.weekNumber() + " exceeds the program's " + weeksCount + " weeks");
            }
            String slotKey = slot.weekNumber() + ":" + slot.dayOfWeek();
            if (!seenSlots.add(slotKey)) {
                throw new InvalidProgramStructureException(
                        "Duplicate slot for week " + slot.weekNumber() + " " + slot.dayOfWeek());
            }
        }
    }

    /**
     * @throws InvalidProgramStructureException if a slot references a template the trainer
     *                                           doesn't own or has deleted
     */
    private Map<Long, WorkoutTemplate> resolveTemplates(Long trainerId, List<ProgramWorkoutRequest> workouts) {
        Map<Long, WorkoutTemplate> templatesById = new HashMap<>();
        for (ProgramWorkoutRequest slot : workouts) {
            templatesById.computeIfAbsent(slot.templateId(), templateId ->
                    workoutTemplateRepository.findByIdAndUserIdAndDeletedAtIsNull(templateId, trainerId)
                            .orElseThrow(() -> new InvalidProgramStructureException(
                                    "Workout template not found: " + templateId)));
        }
        return templatesById;
    }

    private ProgramResponse toResponse(TrainingProgram program) {
        List<ProgramWorkoutResponse> workouts = program.getWorkouts().stream()
                .sorted(Comparator.comparingInt(ProgramWorkout::getWeekNumber)
                        .thenComparing(w -> OccurrenceGenerator.fromCode(w.getDayOfWeek())))
                .map(w -> new ProgramWorkoutResponse(w.getId(), w.getWeekNumber(),
                        OccurrenceGenerator.fromCode(w.getDayOfWeek()), w.getTemplate().getId(),
                        w.getTemplate().getName(), w.getTimeOfDay(), w.getNote()))
                .toList();

        return new ProgramResponse(program.getId(), program.getName(), program.getWeeksCount(),
                workouts, program.getCreatedAt(), program.getUpdatedAt());
    }
}

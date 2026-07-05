package com.lifey.trainer.controller;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.statistics.dto.StatisticsResponse;
import com.lifey.statistics.service.StatisticsService;
import com.lifey.steps.dto.DailyStepCountResponse;
import com.lifey.steps.service.DailyStepCountService;
import com.lifey.trainer.service.TrainerAccessService;
import com.lifey.user.UserAvatar;
import com.lifey.user.UserAvatarRepository;
import com.lifey.weight.dto.WeightResponse;
import com.lifey.weight.service.WeightService;
import com.lifey.workout.session.dto.WorkoutSessionResponse;
import com.lifey.workout.session.service.WorkoutSessionService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.CacheControl;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;

/**
 * Read-only views of a specific client's data for their trainer (docs/personal_trainer/
 * 01-koncepcio-es-folyamatok.md "4. folyamat" and 03-backend-terv.md). Every
 * method reuses the existing per-user service logic via its {@code *ForUser}
 * entry point — nothing here recomputes statistics or re-queries history, it
 * only adds the trainer-relationship guard on top. Meals and water are
 * deliberately not exposed here (see the docs: meals held back as more
 * privacy-sensitive, water explicitly excluded by product decision).
 */
@Tag(name = "Trainer Client Data", description = "Trainer's read-only view of an active client's stats/steps/weight/workouts")
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/v1/trainer/clients/{clientId}")
public class TrainerClientDataController {

    private final TrainerAccessService trainerAccessService;
    private final StatisticsService statisticsService;
    private final DailyStepCountService dailyStepCountService;
    private final WeightService weightService;
    private final WorkoutSessionService workoutSessionService;
    private final UserAvatarRepository userAvatarRepository;
    private final CurrentUserProvider currentUserProvider;

    @Operation(summary = "Client's stats for today")
    @GetMapping("/statistics/daily")
    public StatisticsResponse dailyStatistics(
            @PathVariable Long clientId,
            @Parameter(description = "Anchor date; defaults to the server's current date")
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        requireActiveClient(clientId);
        return statisticsService.dailyForUser(clientId, date != null ? date : LocalDate.now());
    }

    @Operation(summary = "Client's stats for the last 7 days")
    @GetMapping("/statistics/weekly")
    public StatisticsResponse weeklyStatistics(
            @PathVariable Long clientId,
            @Parameter(description = "Anchor date; defaults to the server's current date")
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        requireActiveClient(clientId);
        return statisticsService.weeklyForUser(clientId, date != null ? date : LocalDate.now());
    }

    @Operation(summary = "Client's stats for the last 30 days")
    @GetMapping("/statistics/monthly")
    public StatisticsResponse monthlyStatistics(
            @PathVariable Long clientId,
            @Parameter(description = "Anchor date; defaults to the server's current date")
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        requireActiveClient(clientId);
        return statisticsService.monthlyForUser(clientId, date != null ? date : LocalDate.now());
    }

    @Operation(summary = "Client's daily step count history",
            description = "Optionally bounded to a date range via `from`/`to` (either or both may be omitted).")
    @GetMapping("/steps")
    public List<DailyStepCountResponse> steps(
            @PathVariable Long clientId,
            @Parameter(description = "Inclusive lower bound (yyyy-MM-dd); omit for no lower bound")
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @Parameter(description = "Inclusive upper bound (yyyy-MM-dd); omit for no upper bound")
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        requireActiveClient(clientId);
        return dailyStepCountService.findAllForUser(clientId, from, to);
    }

    @Operation(summary = "Client's weight history",
            description = "Optionally bounded to a date range via `from`/`to` (either or both may be omitted).")
    @GetMapping("/weights")
    public List<WeightResponse> weights(
            @PathVariable Long clientId,
            @Parameter(description = "Inclusive lower bound (yyyy-MM-dd); omit for no lower bound")
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @Parameter(description = "Inclusive upper bound (yyyy-MM-dd); omit for no upper bound")
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        requireActiveClient(clientId);
        return weightService.findAllForUser(clientId, from, to);
    }

    @Operation(summary = "Client's workout session history, paged (newest first), including sets and planned exercises")
    @GetMapping("/workout-sessions")
    public Page<WorkoutSessionResponse> workoutSessions(
            @PathVariable Long clientId,
            @PageableDefault(size = 20, sort = "startedAt", direction = Sort.Direction.DESC) Pageable pageable) {
        requireActiveClient(clientId);
        return workoutSessionService.findPageForUser(clientId, pageable);
    }

    @Operation(summary = "Client's profile picture", description = "404 if the client has no picture set.")
    @GetMapping("/avatar")
    public ResponseEntity<byte[]> avatar(@PathVariable Long clientId) {
        requireActiveClient(clientId);
        UserAvatar avatar = userAvatarRepository.findByUserId(clientId)
                .orElseThrow(() -> new ResourceNotFoundException("No profile picture set"));
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(avatar.getContentType()))
                .cacheControl(CacheControl.noCache().cachePrivate())
                .body(avatar.getImage());
    }

    private void requireActiveClient(Long clientId) {
        trainerAccessService.requireActiveClient(currentUserProvider.getUserId(), clientId);
    }
}

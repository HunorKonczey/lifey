package com.lifey.trainer.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.trainer.ContentAssignmentRepository;
import com.lifey.trainer.ContentType;
import com.lifey.trainer.ProgramAssignmentRepository;
import com.lifey.trainer.TemplateClientPair;
import com.lifey.trainer.WorkoutScheduleRepository;
import com.lifey.trainer.dto.TemplateUsageResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class TemplateUsageServiceImpl implements TemplateUsageService {

    private final ContentAssignmentRepository contentAssignmentRepository;
    private final WorkoutScheduleRepository workoutScheduleRepository;
    private final ProgramAssignmentRepository programAssignmentRepository;
    private final CurrentUserProvider currentUserProvider;

    @Override
    public List<TemplateUsageResponse> usageForCurrentTrainer() {
        Long trainerId = currentUserProvider.getUserId();
        LocalDate today = LocalDate.now(ZoneId.systemDefault());

        Map<Long, Set<Long>> assigned = new TreeMap<>();
        for (TemplateClientPair pair : contentAssignmentRepository.findAssignedPairs(trainerId, ContentType.TEMPLATE)) {
            assigned.computeIfAbsent(pair.getTemplateId(), k -> new LinkedHashSet<>()).add(pair.getClientId());
        }
        // A client running a template through a schedule and through a program counts once.
        Map<Long, Set<Long>> scheduled = new TreeMap<>();
        for (TemplateClientPair pair : workoutScheduleRepository.findLivePairs(trainerId, today)) {
            scheduled.computeIfAbsent(pair.getTemplateId(), k -> new LinkedHashSet<>()).add(pair.getClientId());
        }
        for (TemplateClientPair pair : programAssignmentRepository.findLivePairs(trainerId, today)) {
            scheduled.computeIfAbsent(pair.getTemplateId(), k -> new LinkedHashSet<>()).add(pair.getClientId());
        }

        Set<Long> templateIds = new java.util.TreeSet<>(assigned.keySet());
        templateIds.addAll(scheduled.keySet());
        List<TemplateUsageResponse> result = new ArrayList<>();
        for (Long templateId : templateIds) {
            result.add(new TemplateUsageResponse(
                    templateId,
                    List.copyOf(assigned.getOrDefault(templateId, Set.of())),
                    List.copyOf(scheduled.getOrDefault(templateId, Set.of()))));
        }
        return result;
    }
}

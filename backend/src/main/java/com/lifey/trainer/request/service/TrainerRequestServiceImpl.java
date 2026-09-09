package com.lifey.trainer.request.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.DuplicateResourceException;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.mail.service.MailService;
import com.lifey.superadmin.service.RoleManagementService;
import com.lifey.trainer.request.TrainerRequest;
import com.lifey.trainer.request.TrainerRequestRepository;
import com.lifey.trainer.request.TrainerRequestStatus;
import com.lifey.trainer.request.dto.SuperAdminTrainerRequestResponse;
import com.lifey.trainer.request.dto.TrainerRequestRequest;
import com.lifey.trainer.request.dto.TrainerRequestResponse;
import com.lifey.trainer.request.exception.TrainerRequestAlreadyDecidedException;
import com.lifey.user.Role;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;

/**
 * docs/landing_page/66-trainer-billing-web-plan.md §2 (D-T1). {@link #approve}
 * only grants the role via {@link RoleManagementService} (reused, not
 * duplicated) — resolving this row to {@code APPROVED} and sending the "you're
 * in" email happen in {@code TrainerRequestResolutionListener}, triggered by
 * the same {@code TrainerRoleGrantedEvent} that starts the trial (`64` §4.1).
 * That indirection is deliberate: it also resolves a request when a super
 * admin grants the role through the plain user-management page instead of
 * this queue, exactly as the plan calls for ("the super admin's existing
 * grant action also resolves the request").
 */
@Service
@RequiredArgsConstructor
@Transactional
public class TrainerRequestServiceImpl implements TrainerRequestService {

    private final TrainerRequestRepository trainerRequestRepository;
    private final UserRepository userRepository;
    private final RoleManagementService roleManagementService;
    private final MailService mailService;
    private final CurrentUserProvider currentUserProvider;
    private final Clock clock;

    @Override
    public TrainerRequestResponse submit(Long userId, TrainerRequestRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found: " + userId));
        if (user.getRoles().contains(Role.ROLE_TRAINER)) {
            throw new DuplicateResourceException("You are already a trainer");
        }
        if (trainerRequestRepository.existsByUserIdAndStatus(userId, TrainerRequestStatus.PENDING)) {
            throw new DuplicateResourceException("You already have an open trainer request");
        }

        TrainerRequest trainerRequest = new TrainerRequest();
        trainerRequest.setUser(user);
        trainerRequest.setStatus(TrainerRequestStatus.PENDING);
        trainerRequest.setMotivation(request.motivation());
        trainerRequest.setClientCount(request.clientCount());
        trainerRequest.setSignupSource(request.signupSource());
        trainerRequest.setCreatedAt(clock.instant());
        trainerRequestRepository.save(trainerRequest);

        mailService.sendTrainerRequestNotification(user, request.motivation(), request.clientCount());

        return toResponse(trainerRequest);
    }

    @Override
    @Transactional(readOnly = true)
    public TrainerRequestResponse findMine(Long userId) {
        return trainerRequestRepository.findFirstByUserIdOrderByCreatedAtDesc(userId)
                .map(TrainerRequestServiceImpl::toResponse)
                .orElseThrow(() -> new ResourceNotFoundException("No trainer request found for user " + userId));
    }

    @Override
    @Transactional(readOnly = true)
    public Page<SuperAdminTrainerRequestResponse> findPending(Pageable pageable) {
        return trainerRequestRepository.findByStatus(TrainerRequestStatus.PENDING, pageable)
                .map(TrainerRequestServiceImpl::toSuperAdminResponse);
    }

    @Override
    public void approve(Long requestId) {
        TrainerRequest trainerRequest = getPendingOrThrow(requestId);
        roleManagementService.grant(trainerRequest.getUser().getId(), Role.ROLE_TRAINER);
    }

    @Override
    public void reject(Long requestId) {
        TrainerRequest trainerRequest = getPendingOrThrow(requestId);
        trainerRequest.setStatus(TrainerRequestStatus.REJECTED);
        trainerRequest.setDecidedAt(clock.instant());
        trainerRequest.setDecidedBy(currentUserProvider.getUserId());
        trainerRequestRepository.save(trainerRequest);
    }

    private TrainerRequest getPendingOrThrow(Long requestId) {
        TrainerRequest trainerRequest = trainerRequestRepository.findById(requestId)
                .orElseThrow(() -> new ResourceNotFoundException("Trainer request not found: " + requestId));
        if (trainerRequest.getStatus() != TrainerRequestStatus.PENDING) {
            throw new TrainerRequestAlreadyDecidedException("Trainer request " + requestId + " has already been decided");
        }
        return trainerRequest;
    }

    private static TrainerRequestResponse toResponse(TrainerRequest r) {
        return new TrainerRequestResponse(r.getId(), r.getStatus(), r.getMotivation(), r.getClientCount(),
                r.getCreatedAt(), r.getDecidedAt());
    }

    private static SuperAdminTrainerRequestResponse toSuperAdminResponse(TrainerRequest r) {
        return new SuperAdminTrainerRequestResponse(r.getId(), r.getUser().getId(), r.getUser().getEmail(),
                r.getStatus(), r.getMotivation(), r.getClientCount(), r.getSignupSource(),
                r.getCreatedAt(), r.getDecidedAt());
    }
}

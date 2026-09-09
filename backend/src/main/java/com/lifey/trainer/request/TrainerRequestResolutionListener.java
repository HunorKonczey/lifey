package com.lifey.trainer.request;

import com.lifey.mail.service.MailService;
import com.lifey.superadmin.TrainerRoleGrantedEvent;
import com.lifey.user.User;
import com.lifey.user.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

import java.time.Clock;

/**
 * Resolves any {@code PENDING} trainer request the moment {@code ROLE_TRAINER}
 * is actually granted, regardless of whether the grant came through the
 * dedicated superadmin trainer-requests queue or the plain superadmin
 * user-management page (docs/landing_page/66-trainer-billing-web-plan.md §2:
 * "the super admin's existing grant action also resolves the request"). Plain
 * {@code @EventListener}, same rationale as {@code TrainerTrialListener} —
 * must run inside the same transaction as the grant so the request row and
 * the role are never observably out of sync.
 */
@Component
@RequiredArgsConstructor
@Slf4j
class TrainerRequestResolutionListener {

    private final TrainerRequestRepository trainerRequestRepository;
    private final UserRepository userRepository;
    private final MailService mailService;
    private final Clock clock;

    @EventListener
    void onTrainerRoleGranted(TrainerRoleGrantedEvent event) {
        trainerRequestRepository.findFirstByUserIdAndStatus(event.userId(), TrainerRequestStatus.PENDING)
                .ifPresent(request -> resolve(request, event.actorId()));
    }

    private void resolve(TrainerRequest request, Long actorId) {
        request.setStatus(TrainerRequestStatus.APPROVED);
        request.setDecidedAt(clock.instant());
        request.setDecidedBy(actorId);
        trainerRequestRepository.save(request);

        // A fresh, fully-loaded User — not the lazy `request.getUser()` proxy. MailService's
        // send is @Async, running on a different thread with no Hibernate session open; a
        // still-uninitialized proxy crossing that boundary would throw
        // LazyInitializationException (same reasoning as WelcomeEmailListener).
        User user = userRepository.findById(request.getUser().getId()).orElse(null);
        if (user == null) {
            log.warn("Trainer request {} approved but user {} is missing, skipping approval email",
                    request.getId(), request.getUser().getId());
            return;
        }
        mailService.sendTrainerRequestApproved(user);
    }
}

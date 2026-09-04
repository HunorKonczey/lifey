package com.lifey.trainer.request.service;

import com.lifey.trainer.request.dto.SuperAdminTrainerRequestResponse;
import com.lifey.trainer.request.dto.TrainerRequestRequest;
import com.lifey.trainer.request.dto.TrainerRequestResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

public interface TrainerRequestService {

    /**
     * @throws com.lifey.common.exception.DuplicateResourceException if the user already has
     *         {@code ROLE_TRAINER} or already has an open ({@code PENDING}) request
     */
    TrainerRequestResponse submit(Long userId, TrainerRequestRequest request);

    /**
     * The user's most recent request, of any status — lets {@code /admin/pending} poll.
     *
     * @throws com.lifey.common.exception.ResourceNotFoundException if the user has never submitted one
     */
    TrainerRequestResponse findMine(Long userId);

    Page<SuperAdminTrainerRequestResponse> findPending(Pageable pageable);

    /**
     * Grants {@code ROLE_TRAINER} (reusing {@code RoleManagementService}, which starts the
     * trial) and resolves this request as {@code APPROVED}.
     *
     * @throws com.lifey.common.exception.ResourceNotFoundException if no such request exists
     * @throws com.lifey.trainer.request.exception.TrainerRequestAlreadyDecidedException if it isn't {@code PENDING}
     */
    void approve(Long requestId);

    /**
     * @throws com.lifey.common.exception.ResourceNotFoundException if no such request exists
     * @throws com.lifey.trainer.request.exception.TrainerRequestAlreadyDecidedException if it isn't {@code PENDING}
     */
    void reject(Long requestId);
}

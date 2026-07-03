package com.lifey.trainer.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.trainer.TrainerClient;
import com.lifey.trainer.TrainerClientMapper;
import com.lifey.trainer.TrainerClientRepository;
import com.lifey.trainer.TrainerClientStatus;
import com.lifey.trainer.dto.MyTrainerResponse;
import com.lifey.trainer.dto.TrainerClientResponse;
import com.lifey.trainer.exception.NotYourClientException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional
public class TrainerAccessServiceImpl implements TrainerAccessService {

    private final TrainerClientRepository trainerClientRepository;
    private final CurrentUserProvider currentUserProvider;

    @Override
    @Transactional(readOnly = true)
    public TrainerClient requireActiveClient(Long trainerId, Long clientId) {
        return trainerClientRepository.findByTrainerIdAndClientIdAndStatus(trainerId, clientId, TrainerClientStatus.ACTIVE)
                .orElseThrow(() -> new NotYourClientException("Not an active client: " + clientId));
    }

    @Override
    @Transactional(readOnly = true)
    public List<TrainerClientResponse> findActiveClientsForTrainer() {
        return trainerClientRepository.findByTrainerIdAndStatusOrderByRespondedAtDesc(
                        currentUserProvider.getUserId(), TrainerClientStatus.ACTIVE)
                .stream()
                .map(TrainerClientMapper::toClientResponse)
                .toList();
    }

    @Override
    public void revokeClient(Long clientId) {
        TrainerClient relationship = requireActiveClient(currentUserProvider.getUserId(), clientId);
        revoke(relationship);
    }

    @Override
    @Transactional(readOnly = true)
    public List<MyTrainerResponse> findActiveTrainersForClient() {
        return trainerClientRepository.findByClientIdAndStatusOrderByRespondedAtDesc(
                        currentUserProvider.getUserId(), TrainerClientStatus.ACTIVE)
                .stream()
                .map(TrainerClientMapper::toMyTrainerResponse)
                .toList();
    }

    @Override
    public void leaveTrainer(Long trainerId) {
        TrainerClient relationship = trainerClientRepository.findByTrainerIdAndClientIdAndStatus(
                        trainerId, currentUserProvider.getUserId(), TrainerClientStatus.ACTIVE)
                .orElseThrow(() -> new ResourceNotFoundException("Trainer not found: " + trainerId));
        revoke(relationship);
    }

    private void revoke(TrainerClient relationship) {
        relationship.setStatus(TrainerClientStatus.REVOKED);
        relationship.setRevokedAt(Instant.now());
        relationship.setRevokedBy(currentUserProvider.getUserId());
    }
}

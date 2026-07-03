package com.lifey.trainer.service;

import com.lifey.trainer.dto.AssignmentListItemResponse;
import com.lifey.trainer.dto.AssignmentRequest;
import com.lifey.trainer.dto.AssignmentResponse;

import java.util.List;

public interface ContentAssignmentService {

    AssignmentResponse assign(AssignmentRequest request);

    List<AssignmentListItemResponse> findForClient(Long clientId);
}

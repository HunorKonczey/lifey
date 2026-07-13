package com.lifey.trainer.service;

import com.lifey.trainer.dto.ProgramRequest;
import com.lifey.trainer.dto.ProgramResponse;
import com.lifey.trainer.dto.ProgramSummaryResponse;

import java.util.List;

public interface TrainingProgramService {

    ProgramResponse create(ProgramRequest request);

    List<ProgramSummaryResponse> findAll();

    ProgramResponse findById(Long programId);

    /** Full replace of name/weeks/slots. Does not touch existing assignments. */
    ProgramResponse update(Long programId, ProgramRequest request);

    /** Soft delete — allowed with assignments in flight, since they are materialized snapshots. */
    void delete(Long programId);
}

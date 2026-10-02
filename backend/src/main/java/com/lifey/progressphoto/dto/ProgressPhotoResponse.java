package com.lifey.progressphoto.dto;

import com.lifey.progressphoto.PhotoPose;

import java.time.Instant;
import java.time.LocalDate;

public record ProgressPhotoResponse(
        Long id,
        LocalDate takenOn,
        PhotoPose pose,
        String note,
        Instant createdAt,
        Instant updatedAt
) {
}

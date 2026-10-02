package com.lifey.progressphoto;

import com.lifey.progressphoto.dto.ProgressPhotoResponse;

public final class ProgressPhotoMapper {

    private ProgressPhotoMapper() {
    }

    public static ProgressPhotoResponse toResponse(ProgressPhoto photo) {
        return new ProgressPhotoResponse(
                photo.getId(),
                photo.getTakenOn(),
                photo.getPose(),
                photo.getNote(),
                photo.getCreatedAt(),
                photo.getUpdatedAt()
        );
    }
}

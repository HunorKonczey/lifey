package com.lifey.progressphoto.dto;

import com.lifey.common.validation.NotFutureDate;
import com.lifey.progressphoto.PhotoPose;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;

/** Full replacement of a photo's metadata: a null {@code note} clears it. */
public record ProgressPhotoUpdateRequest(

        @NotNull
        @NotFutureDate
        LocalDate takenOn,

        @NotNull
        PhotoPose pose,

        @Size(max = 500)
        String note
) {
}

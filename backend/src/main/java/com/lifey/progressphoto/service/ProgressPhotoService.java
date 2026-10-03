package com.lifey.progressphoto.service;

import com.lifey.progressphoto.PhotoPose;
import com.lifey.progressphoto.ProgressPhotoImage;
import com.lifey.progressphoto.dto.ProgressPhotoResponse;
import com.lifey.progressphoto.dto.ProgressPhotoUpdateRequest;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDate;
import java.util.List;

/**
 * Current-user progress photos (docs/80). Deliberately has no cross-user
 * variant and no trainer access (§2.6) — body photos are private to the owner.
 */
public interface ProgressPhotoService {

    /** Newest first by {@code takenOn}, ties broken by newest id. */
    List<ProgressPhotoResponse> findAll();

    ProgressPhotoResponse create(MultipartFile file, LocalDate takenOn, PhotoPose pose, String note);

    ProgressPhotoResponse update(Long id, ProgressPhotoUpdateRequest request);

    /** The stored bytes of an owned photo; 404 for a missing or foreign id. */
    ProgressPhotoImage findImage(Long id);

    /** Hard delete of the photo and its image (docs/80 §6). */
    void delete(Long id);
}

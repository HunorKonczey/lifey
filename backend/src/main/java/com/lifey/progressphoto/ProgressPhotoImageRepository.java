package com.lifey.progressphoto;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

/**
 * Not user-scoped by itself: callers must have resolved the photo through
 * {@link ProgressPhotoRepository#findByIdAndUserId} first, which is what
 * ProgressPhotoServiceImpl does for every method.
 */
public interface ProgressPhotoImageRepository extends JpaRepository<ProgressPhotoImage, Long> {

    Optional<ProgressPhotoImage> findByPhotoId(Long photoId);

    void deleteByPhotoId(Long photoId);
}

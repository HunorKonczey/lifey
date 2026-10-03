package com.lifey.progressphoto;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface ProgressPhotoRepository extends JpaRepository<ProgressPhoto, Long> {

    List<ProgressPhoto> findAllByUserIdOrderByTakenOnDescIdDesc(Long userId);

    /** Every single-photo lookup goes through here — a bare findById would leak other users' photos. */
    Optional<ProgressPhoto> findByIdAndUserId(Long id, Long userId);
}

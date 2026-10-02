package com.lifey.progressphoto.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.common.image.ImageReencoder;
import com.lifey.progressphoto.PhotoPose;
import com.lifey.progressphoto.ProgressPhoto;
import com.lifey.progressphoto.ProgressPhotoImage;
import com.lifey.progressphoto.ProgressPhotoImageRepository;
import com.lifey.progressphoto.ProgressPhotoMapper;
import com.lifey.progressphoto.ProgressPhotoRepository;
import com.lifey.progressphoto.dto.ProgressPhotoResponse;
import com.lifey.progressphoto.dto.ProgressPhotoUpdateRequest;
import com.lifey.progressphoto.exception.InvalidProgressPhotoException;
import com.lifey.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.awt.image.BufferedImage;
import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

@Service
@Transactional
@RequiredArgsConstructor
public class ProgressPhotoServiceImpl implements ProgressPhotoService {

    /** Looked at full-screen and compared side by side, so softer than the 1024 px recipe photos (docs/80 §2.4). */
    static final int MAIN_MAX_SIDE = 1600;
    static final int THUMBNAIL_SIZE = 256;
    static final int NOTE_MAX_LENGTH = 500;

    private final ProgressPhotoRepository repository;
    private final ProgressPhotoImageRepository imageRepository;
    private final UserRepository userRepository;
    private final CurrentUserProvider currentUserProvider;

    @Override
    @Transactional(readOnly = true)
    public List<ProgressPhotoResponse> findAll() {
        return repository.findAllByUserIdOrderByTakenOnDescIdDesc(currentUserProvider.getUserId()).stream()
                .map(ProgressPhotoMapper::toResponse)
                .toList();
    }

    @Override
    public ProgressPhotoResponse create(MultipartFile file, LocalDate takenOn, PhotoPose pose, String note) {
        requireValidMetadata(takenOn, note);
        // Decode first: an undecodable upload must fail before anything is written.
        BufferedImage source = ImageReencoder.decode(inputStream(file));

        Instant now = Instant.now();
        ProgressPhoto photo = new ProgressPhoto();
        photo.setUser(userRepository.getReferenceById(currentUserProvider.getUserId()));
        photo.setTakenOn(takenOn);
        photo.setPose(pose == null ? PhotoPose.OTHER : pose);
        photo.setNote(blankToNull(note));
        photo.setCreatedAt(now);
        photo.setUpdatedAt(now);
        ProgressPhoto saved = repository.save(photo);

        // Only re-encoded bytes are ever stored — that is what strips EXIF/GPS (docs/80 §10).
        ProgressPhotoImage image = new ProgressPhotoImage();
        image.setPhoto(saved);
        image.setImage(ImageReencoder.boundedJpeg(source, MAIN_MAX_SIDE));
        image.setThumbnail(ImageReencoder.squareJpeg(source, THUMBNAIL_SIZE));
        image.setContentType(ImageReencoder.CONTENT_TYPE);
        image.setUpdatedAt(now);
        imageRepository.save(image);

        return ProgressPhotoMapper.toResponse(saved);
    }

    @Override
    public ProgressPhotoResponse update(Long id, ProgressPhotoUpdateRequest request) {
        requireValidMetadata(request.takenOn(), request.note());
        ProgressPhoto photo = getOwned(id);
        photo.setTakenOn(request.takenOn());
        photo.setPose(request.pose());
        photo.setNote(blankToNull(request.note()));
        photo.setUpdatedAt(Instant.now());
        return ProgressPhotoMapper.toResponse(photo);
    }

    @Override
    @Transactional(readOnly = true)
    public ProgressPhotoImage findImage(Long id) {
        getOwned(id);
        return imageRepository.findByPhotoId(id)
                .orElseThrow(() -> new ResourceNotFoundException("No image stored for progress photo: " + id));
    }

    @Override
    public void delete(Long id) {
        ProgressPhoto photo = getOwned(id);
        imageRepository.deleteByPhotoId(id);
        repository.delete(photo);
    }

    private ProgressPhoto getOwned(Long id) {
        return repository.findByIdAndUserId(id, currentUserProvider.getUserId())
                .orElseThrow(() -> new ResourceNotFoundException("Progress photo not found: " + id));
    }

    private static void requireValidMetadata(LocalDate takenOn, String note) {
        if (takenOn == null) {
            throw new InvalidProgressPhotoException("takenOn is required");
        }
        if (takenOn.isAfter(LocalDate.now().plusDays(1))) {
            // One day of slack so a client ahead of the server's timezone is not rejected for "today".
            throw new InvalidProgressPhotoException("takenOn must not be in the future");
        }
        if (note != null && note.length() > NOTE_MAX_LENGTH) {
            throw new InvalidProgressPhotoException("note must be at most " + NOTE_MAX_LENGTH + " characters");
        }
    }

    private static String blankToNull(String note) {
        return note == null || note.isBlank() ? null : note.strip();
    }

    private static InputStream inputStream(MultipartFile file) {
        try {
            return file.getInputStream();
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }
}

package com.lifey.user.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.user.AvatarSource;
import com.lifey.user.ImageReencoder;
import com.lifey.user.UserAvatar;
import com.lifey.user.UserAvatarRepository;
import com.lifey.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.time.Instant;

@Service
@Transactional
@RequiredArgsConstructor
public class UserAvatarServiceImpl implements UserAvatarService {

    private final UserAvatarRepository repository;
    private final UserRepository userRepository;
    private final CurrentUserProvider currentUserProvider;

    @Override
    @Transactional(readOnly = true)
    public UserAvatar find() {
        return repository.findByUserId(currentUserProvider.getUserId())
                .orElseThrow(() -> new ResourceNotFoundException("No profile picture set"));
    }

    @Override
    public void upload(MultipartFile file) {
        byte[] jpeg = reencode(file);
        Long userId = currentUserProvider.getUserId();

        UserAvatar avatar = repository.findByUserId(userId)
                .orElseGet(() -> {
                    UserAvatar created = new UserAvatar();
                    created.setUser(userRepository.getReferenceById(userId));
                    return created;
                });
        avatar.setImage(jpeg);
        avatar.setContentType(ImageReencoder.CONTENT_TYPE);
        avatar.setSource(AvatarSource.UPLOAD);
        avatar.setUpdatedAt(Instant.now());
        repository.save(avatar);
    }

    @Override
    public void delete() {
        repository.deleteByUserId(currentUserProvider.getUserId());
    }

    private byte[] reencode(MultipartFile file) {
        try {
            return ImageReencoder.toSquareJpeg(file.getInputStream());
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }
}

package com.lifey.user.service;

import com.lifey.user.UserAvatar;
import org.springframework.web.multipart.MultipartFile;

/**
 * Manages the current user's profile picture. Always resolves the user from
 * the security context (see docs/22-profile-picture-plan.md) — no userId
 * parameters.
 */
public interface UserAvatarService {

    /**
     * @throws com.lifey.common.exception.ResourceNotFoundException if the user has no avatar set
     */
    UserAvatar find();

    /**
     * Validates, re-encodes (center-crop + resize + strip metadata) and stores
     * the given file, replacing any existing avatar.
     *
     * @throws com.lifey.common.exception.InvalidImageException if the file isn't a decodable JPEG/PNG
     */
    void upload(MultipartFile file);

    void delete();
}

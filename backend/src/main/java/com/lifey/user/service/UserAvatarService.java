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
     * Another user's picture, for the one place two accounts see each other:
     * the chat renders the peer in every row and thread header
     * (docs/chat/40-trainer-chat-plan.md §11).
     *
     * <p>Readable only by someone with an ACTIVE trainer-client link to
     * {@code userId} — and by the user themselves, so a caller does not have to
     * branch on "is this me". Anyone else gets the same answer as for a user
     * with no picture: not found, never a 403, so this cannot be used to probe
     * which accounts exist.
     *
     * @throws com.lifey.common.exception.ResourceNotFoundException if there is no
     *         picture to show, or the caller is not allowed to see it
     */
    UserAvatar findForPeer(Long userId);

    /**
     * Validates, re-encodes (center-crop + resize + strip metadata) and stores
     * the given file, replacing any existing avatar.
     *
     * @throws com.lifey.common.exception.InvalidImageException if the file isn't a decodable JPEG/PNG
     */
    void upload(MultipartFile file);

    void delete();
}

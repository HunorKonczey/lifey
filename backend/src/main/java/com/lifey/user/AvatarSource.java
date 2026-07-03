package com.lifey.user;

/**
 * Where a stored {@link UserAvatar} came from. GOOGLE rows are only ever
 * written when the user has no avatar yet — see UserAvatarServiceImpl.
 */
public enum AvatarSource {
    UPLOAD,
    GOOGLE
}

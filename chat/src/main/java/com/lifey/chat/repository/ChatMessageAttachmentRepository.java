package com.lifey.chat.repository;

import com.lifey.chat.entity.ChatMessageAttachment;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface ChatMessageAttachmentRepository extends JpaRepository<ChatMessageAttachment, Long> {

    Optional<ChatMessageAttachment> findByMessageId(Long messageId);

    void deleteByMessageId(Long messageId);
}

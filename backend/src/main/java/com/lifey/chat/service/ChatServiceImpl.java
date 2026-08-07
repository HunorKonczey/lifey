package com.lifey.chat.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.chat.ChatMapper;
import com.lifey.chat.ChatMessageDeletedEvent;
import com.lifey.chat.ChatMessageStoredEvent;
import com.lifey.chat.ChatMetrics;
import com.lifey.chat.ChatProperties;
import com.lifey.chat.ChatReadCursorEvent;
import com.lifey.chat.dto.ConversationListResponse;
import com.lifey.chat.dto.ConversationResponse;
import com.lifey.chat.dto.MessageListResponse;
import com.lifey.chat.dto.SendMessageRequest;
import com.lifey.chat.entity.ChatConversation;
import com.lifey.chat.entity.ChatMessage;
import com.lifey.chat.entity.ChatMessageAttachment;
import com.lifey.chat.entity.ChatParticipant;
import com.lifey.chat.exception.AttachmentTooLargeException;
import com.lifey.chat.exception.ChatDisabledException;
import com.lifey.chat.exception.ConversationArchivedException;
import com.lifey.chat.exception.InvalidMessageBodyException;
import com.lifey.chat.repository.ChatConversationRepository;
import com.lifey.chat.repository.ChatMessageAttachmentRepository;
import com.lifey.chat.repository.ChatMessageRepository;
import com.lifey.chat.repository.ChatParticipantRepository;
import com.lifey.chat.repository.ConversationUnreadCount;
import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.common.image.ImageReencoder;
import com.lifey.trainer.TrainerClientRepository;
import com.lifey.trainer.TrainerClientStatus;
import com.lifey.trainer.entity.TrainerClient;
import com.lifey.user.User;
import lombok.RequiredArgsConstructor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Transactional
public class ChatServiceImpl implements ChatService {

    private final ChatConversationRepository conversationRepository;
    private final ChatMessageRepository messageRepository;
    private final ChatMessageAttachmentRepository attachmentRepository;
    private final ChatParticipantRepository participantRepository;
    private final TrainerClientRepository trainerClientRepository;
    private final CurrentUserProvider currentUserProvider;
    private final ChatRateLimiter rateLimiter;
    private final ChatMetrics metrics;
    private final ChatProperties properties;
    private final ApplicationEventPublisher eventPublisher;

    @Override
    @Transactional(readOnly = true)
    public ConversationListResponse getConversations() {
        Long viewerId = currentUserProvider.getUserId();
        List<ChatConversation> conversations = conversationRepository.findAllForParticipant(viewerId);

        Map<Long, Long> unreadByConversation = messageRepository.countUnreadByConversation(viewerId).stream()
                .collect(Collectors.toMap(ConversationUnreadCount::getConversationId,
                        ConversationUnreadCount::getUnreadCount));

        // One batch fetch instead of a preview query per row.
        Set<Long> previewIds = conversations.stream()
                .map(ChatConversation::getLastMessageId)
                .filter(Objects::nonNull)
                .collect(Collectors.toSet());
        Map<Long, ChatMessage> previews = messageRepository.findAllById(previewIds).stream()
                .collect(Collectors.toMap(ChatMessage::getId, Function.identity()));

        // Both sides' participant rows, batched for the same reason as the
        // previews: the tick marks and the mute flag would otherwise cost two
        // queries per row.
        Map<Boolean, Map<Long, ChatParticipant>> participants = participantRepository
                .findAllForConversations(conversations.stream().map(ChatConversation::getId).toList())
                .stream()
                .collect(Collectors.partitioningBy(
                        p -> p.getUser().getId().equals(viewerId),
                        Collectors.toMap(p -> p.getConversation().getId(), Function.identity())));
        Map<Long, ChatParticipant> mine = participants.get(true);
        Map<Long, ChatParticipant> theirs = participants.get(false);

        List<ConversationResponse> items = conversations.stream()
                .map(conversation -> ChatMapper.toConversationResponse(
                        conversation,
                        viewerId,
                        previews.get(conversation.getLastMessageId()),
                        unreadByConversation.getOrDefault(conversation.getId(), 0L),
                        theirs.get(conversation.getId()),
                        mine.get(conversation.getId())))
                .toList();
        return new ConversationListResponse(items);
    }

    @Override
    public OpenConversationResult openConversation(Long trainerClientId) {
        Long callerId = currentUserProvider.getUserId();
        TrainerClient relationship = trainerClientRepository.findById(trainerClientId)
                .filter(link -> link.getStatus() == TrainerClientStatus.ACTIVE)
                .filter(link -> isParticipant(link, callerId))
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Active trainer-client relationship not found: " + trainerClientId));
        return openFor(relationship, callerId);
    }

    @Override
    public OpenConversationResult openConversationWithUser(Long peerUserId) {
        Long callerId = currentUserProvider.getUserId();
        // Either direction: the caller may be the trainer of the peer, or their client.
        TrainerClient relationship = trainerClientRepository
                .findByTrainerIdAndClientIdAndStatus(callerId, peerUserId, TrainerClientStatus.ACTIVE)
                .or(() -> trainerClientRepository
                        .findByTrainerIdAndClientIdAndStatus(peerUserId, callerId, TrainerClientStatus.ACTIVE))
                .orElseThrow(() -> new ResourceNotFoundException(
                        "No active trainer-client relationship with user: " + peerUserId));
        return openFor(relationship, callerId);
    }

    private OpenConversationResult openFor(TrainerClient relationship, Long callerId) {
        Optional<ChatConversation> existing = conversationRepository.findByTrainerClientId(relationship.getId());
        if (existing.isPresent()) {
            return new OpenConversationResult(toResponse(existing.get(), callerId), false);
        }

        ChatConversation conversation = new ChatConversation();
        conversation.setTrainerClient(relationship);
        conversation.setTrainer(relationship.getTrainer());
        conversation.setClient(relationship.getClient());
        conversation.setCreatedAt(Instant.now());
        conversationRepository.save(conversation);

        participantRepository.saveAll(List.of(
                newParticipant(conversation, relationship.getTrainer()),
                newParticipant(conversation, relationship.getClient())));

        return new OpenConversationResult(toResponse(conversation, callerId), true);
    }

    @Override
    @Transactional(readOnly = true)
    public MessageListResponse listMessages(Long conversationId, Long before, Long after, Integer limit) {
        Long callerId = currentUserProvider.getUserId();
        requireParticipation(conversationId, callerId);

        int size = pageSize(limit);
        // One extra row is the cheapest possible "is there more?" probe.
        Pageable page = PageRequest.of(0, size + 1);

        List<ChatMessage> rows;
        boolean ascending = false;
        if (after != null) {
            rows = messageRepository.findPageAfter(conversationId, after, page);
            ascending = true;
        } else if (before != null) {
            rows = messageRepository.findPageBefore(conversationId, before, page);
        } else {
            rows = messageRepository.findLatestPage(conversationId, page);
        }

        boolean hasMore = rows.size() > size;
        List<ChatMessage> pageRows = new ArrayList<>(hasMore ? rows.subList(0, size) : rows);
        if (ascending) {
            // The response contract is always newest-first, whichever way we walked.
            Collections.reverse(pageRows);
        }
        return new MessageListResponse(pageRows.stream().map(ChatMapper::toMessageResponse).toList(), hasMore);
    }

    @Override
    @Transactional(readOnly = true)
    public MessageListResponse searchMessages(Long conversationId, String query, Long before, Integer limit) {
        Long callerId = currentUserProvider.getUserId();
        requireParticipation(conversationId, callerId);

        String term = query == null ? "" : query.trim();
        if (term.length() < properties.searchMinLength()) {
            // Not an error: the clients search as you type, so they legitimately
            // ask with one character while the user is still typing.
            return new MessageListResponse(List.of(), false);
        }

        int size = pageSize(limit);
        List<ChatMessage> rows = messageRepository.searchInConversation(
                conversationId, containsPattern(term), before, PageRequest.of(0, size + 1));

        boolean hasMore = rows.size() > size;
        List<ChatMessage> pageRows = hasMore ? rows.subList(0, size) : rows;
        return new MessageListResponse(pageRows.stream().map(ChatMapper::toMessageResponse).toList(), hasMore);
    }

    /**
     * Turns a search term into a LIKE pattern, escaping the wildcards so the
     * text is matched literally — someone looking for "50%" is looking for a
     * percent sign, not for everything. Paired with {@code escape '!'} in the
     * query, so {@code !} itself has to be escaped first.
     */
    private static String containsPattern(String term) {
        String escaped = term
                .replace("!", "!!")
                .replace("%", "!%")
                .replace("_", "!_");
        return "%" + escaped + "%";
    }

    @Override
    public SendMessageResult sendMessage(Long conversationId, SendMessageRequest request) {
        return store(conversationId, request.body(), request.clientMessageId(), null);
    }

    @Override
    public SendMessageResult sendMessage(Long conversationId, String body, String clientMessageId,
                                         MultipartFile image) {
        return store(conversationId, body, clientMessageId, image);
    }

    private SendMessageResult store(Long conversationId, String rawBody, String clientMessageId,
                                    MultipartFile image) {
        Long senderId = currentUserProvider.getUserId();
        ChatConversation conversation = requireParticipation(conversationId, senderId);

        if (!properties.enabled()) {
            throw new ChatDisabledException("Chat is temporarily unavailable");
        }
        if (conversation.getArchivedAt() != null) {
            throw new ConversationArchivedException("Conversation is archived: " + conversationId);
        }

        // Replay of an already-stored send: return it untouched and don't spend
        // rate-limit budget on a retry that isn't new traffic. With an image
        // this also means the bytes are never re-uploaded — the retry of a
        // half-finished upload costs one round trip, not another megabyte.
        Optional<ChatMessage> stored =
                messageRepository.findByConversationIdAndClientMessageId(conversationId, clientMessageId);
        if (stored.isPresent()) {
            return new SendMessageResult(ChatMapper.toMessageResponse(stored.get()), false);
        }

        boolean hasImage = image != null && !image.isEmpty();
        String body = rawBody == null ? "" : rawBody.trim();
        // An image on its own is a complete message; the caption is optional.
        if (body.isEmpty() && !hasImage) {
            throw new InvalidMessageBodyException("Message body must not be blank");
        }
        if (body.length() > properties.maxBodyLength()) {
            throw new InvalidMessageBodyException(
                    "Message body exceeds " + properties.maxBodyLength() + " characters");
        }

        // Before the decode, not after: the rate limit exists to bound exactly
        // this kind of work, and re-encoding an image is the expensive part.
        rateLimiter.requireSendAllowance(senderId);

        // Decoded before the message row is written, so a picture that turns
        // out to be unreadable fails the whole send instead of leaving an
        // empty bubble on the other side.
        ReencodedImage reencoded = hasImage ? reencode(image) : null;

        Instant now = Instant.now();
        ChatMessage message = new ChatMessage();
        message.setConversation(conversation);
        message.setSender(senderOf(conversation, senderId));
        message.setBody(body.isEmpty() ? null : body);
        message.setClientMessageId(clientMessageId);
        message.setCreatedAt(now);
        if (reencoded != null) {
            message.setAttachmentWidth(reencoded.width());
            message.setAttachmentHeight(reencoded.height());
            message.setAttachmentByteSize(reencoded.image().length);
        }
        messageRepository.save(message);

        if (reencoded != null) {
            ChatMessageAttachment attachment = new ChatMessageAttachment();
            attachment.setMessage(message);
            attachment.setImage(reencoded.image());
            attachment.setThumbnail(reencoded.thumbnail());
            attachment.setContentType(ImageReencoder.CONTENT_TYPE);
            attachment.setCreatedAt(now);
            attachmentRepository.save(attachment);
        }

        metrics.messageSent(reencoded == null ? "text" : "image");

        conversation.setLastMessageAt(now);
        conversation.setLastMessageId(message.getId());
        // Sending is reading: without this the sender's own message would count
        // as unread for them until they happened to open the thread.
        participantRepository.findByConversationIdAndUserId(conversationId, senderId)
                .ifPresent(participant -> advanceCursor(participant, message.getId(), now));

        // Consumed after commit (see ChatNotificationServiceImpl) — a failed
        // push must never roll back a message the sender already saw land.
        eventPublisher.publishEvent(new ChatMessageStoredEvent(message.getId()));

        return new SendMessageResult(ChatMapper.toMessageResponse(message), true);
    }

    @Override
    public void markRead(Long conversationId, Long lastReadMessageId) {
        Long callerId = currentUserProvider.getUserId();
        ChatConversation conversation = requireParticipation(conversationId, callerId);
        if (conversation.getLastMessageId() == null) {
            return;
        }
        // Clamp instead of validating the id: a client racing ahead of what the
        // server has stored is a normal offline artefact, not an error.
        long target = Math.min(lastReadMessageId, conversation.getLastMessageId());
        boolean advanced = participantRepository.findByConversationIdAndUserId(conversationId, callerId)
                .map(participant -> advanceCursor(participant, target, Instant.now()))
                .orElse(false);

        // Only a real advance is worth a frame: the client calls this on every
        // scroll to the bottom, and most of those change nothing.
        if (advanced) {
            eventPublisher.publishEvent(new ChatReadCursorEvent(conversationId, callerId));
        }
    }

    @Override
    @Transactional(readOnly = true)
    public ChatMessageAttachment findAttachment(Long messageId) {
        Long callerId = currentUserProvider.getUserId();
        ChatMessage message = messageRepository.findById(messageId)
                .orElseThrow(() -> new ResourceNotFoundException("Message not found: " + messageId));
        // The guard is the thread, not the sender: both sides can look at a
        // picture in a conversation they are part of.
        requireParticipation(message.getConversation().getId(), callerId);
        return attachmentRepository.findByMessageId(messageId)
                .orElseThrow(() -> new ResourceNotFoundException("No attachment on message: " + messageId));
    }

    @Override
    public void deleteMessage(Long messageId) {
        Long callerId = currentUserProvider.getUserId();
        ChatMessage message = messageRepository.findById(messageId)
                .filter(stored -> stored.getSender().getId().equals(callerId))
                .orElseThrow(() -> new ResourceNotFoundException("Message not found: " + messageId));
        if (message.getDeletedAt() != null) {
            return;
        }
        message.setDeletedAt(Instant.now());
        // The row survives as a tombstone; the text itself is genuinely gone.
        message.setBody(null);
        // And so is the picture. "Deleted" that left the image downloadable
        // would be a lie — the bytes go, not just the reference to them.
        if (message.hasAttachment()) {
            attachmentRepository.deleteByMessageId(messageId);
            message.clearAttachment();
        }

        // The one write that changes a row the peer may already be showing, so
        // it needs a frame of its own — their gap-fill only walks forward.
        eventPublisher.publishEvent(new ChatMessageDeletedEvent(messageId));
    }

    @Override
    public void mute(Long conversationId, Instant mutedUntil) {
        Long callerId = currentUserProvider.getUserId();
        // Participation guard first: muting a thread you are not in should look
        // exactly like the thread not existing, same as every other route (§4).
        requireParticipation(conversationId, callerId);
        participantRepository.findByConversationIdAndUserId(conversationId, callerId)
                .ifPresent(participant -> participant.setMutedUntil(mutedUntil));
    }

    @Override
    public void archiveForPair(Long trainerId, Long clientId) {
        Instant now = Instant.now();
        conversationRepository.findByTrainerIdAndClientIdAndArchivedAtIsNull(trainerId, clientId)
                .forEach(conversation -> conversation.setArchivedAt(now));
    }

    /** What one upload becomes: a bounded JPEG, a square thumbnail, and the size to reserve. */
    private record ReencodedImage(byte[] image, byte[] thumbnail, int width, int height) {
    }

    /**
     * Runs an upload through the shared {@code ImageReencoder} (the same
     * pipeline as avatars and recipe photos): decoding validates it, and since
     * only pixels survive the round trip, EXIF and GPS are stripped with it.
     */
    private ReencodedImage reencode(MultipartFile file) {
        if (file.getSize() > properties.attachmentMaxBytes()) {
            throw new AttachmentTooLargeException(
                    "Attachment exceeds " + properties.attachmentMaxBytes() + " bytes");
        }
        BufferedImage source = ImageReencoder.decode(inputStream(file));
        byte[] image = ImageReencoder.boundedJpeg(source, properties.attachmentMaxSide());
        // Bounded, not square-cropped: the bubble reserves the picture's real
        // aspect ratio from the metadata, so a center-cropped thumbnail would
        // be cropped a second time on the way into that box.
        byte[] thumbnail = ImageReencoder.boundedJpeg(source, properties.attachmentThumbnailSize());
        // Read back from the stored bytes rather than scaling the source
        // dimensions by hand: the client reserves its box from these numbers,
        // and an off-by-one there is a visible jump when the image loads.
        BufferedImage storedImage = ImageReencoder.decode(new ByteArrayInputStream(image));
        return new ReencodedImage(image, thumbnail, storedImage.getWidth(), storedImage.getHeight());
    }

    private static InputStream inputStream(MultipartFile file) {
        try {
            return file.getInputStream();
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    private ChatConversation requireParticipation(Long conversationId, Long userId) {
        return conversationRepository.findByIdForParticipant(conversationId, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Conversation not found: " + conversationId));
    }

    private ConversationResponse toResponse(ChatConversation conversation, Long viewerId) {
        ChatMessage lastMessage = conversation.getLastMessageId() == null
                ? null
                : messageRepository.findById(conversation.getLastMessageId()).orElse(null);
        long unreadCount = messageRepository.countUnread(conversation.getId(), viewerId);
        ChatParticipant peerParticipant = participantRepository
                .findByConversationIdAndUserId(conversation.getId(), ChatMapper.peerIdOf(conversation, viewerId))
                .orElse(null);
        ChatParticipant viewerParticipant = participantRepository
                .findByConversationIdAndUserId(conversation.getId(), viewerId)
                .orElse(null);
        return ChatMapper.toConversationResponse(
                conversation, viewerId, lastMessage, unreadCount, peerParticipant, viewerParticipant);
    }

    /** @return true if the cursor actually moved forward */
    private static boolean advanceCursor(ChatParticipant participant, Long messageId, Instant now) {
        if (participant.getLastReadMessageId() != null && participant.getLastReadMessageId() >= messageId) {
            return false;
        }
        participant.setLastReadMessageId(messageId);
        participant.setLastReadAt(now);
        // Reading is a stronger statement than delivery, so it drags that
        // cursor along — otherwise a thread read offline would show as
        // "delivered but not read" forever.
        if (participant.getLastDeliveredMessageId() == null
                || participant.getLastDeliveredMessageId() < messageId) {
            participant.setLastDeliveredMessageId(messageId);
        }
        return true;
    }

    private static ChatParticipant newParticipant(ChatConversation conversation, User user) {
        ChatParticipant participant = new ChatParticipant();
        participant.setConversation(conversation);
        participant.setUser(user);
        return participant;
    }

    private static boolean isParticipant(TrainerClient relationship, Long userId) {
        return relationship.getTrainer().getId().equals(userId)
                || relationship.getClient().getId().equals(userId);
    }

    /** The conversation already holds both users, so the sender needs no extra lookup. */
    private static User senderOf(ChatConversation conversation, Long senderId) {
        return conversation.getTrainer().getId().equals(senderId)
                ? conversation.getTrainer()
                : conversation.getClient();
    }

    private int pageSize(Integer requested) {
        if (requested == null || requested <= 0) {
            return properties.defaultPageSize();
        }
        return Math.min(requested, properties.maxPageSize());
    }
}

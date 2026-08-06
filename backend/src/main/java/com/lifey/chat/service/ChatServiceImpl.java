package com.lifey.chat.service;

import com.lifey.auth.CurrentUserProvider;
import com.lifey.chat.ChatMapper;
import com.lifey.chat.ChatMessageStoredEvent;
import com.lifey.chat.ChatProperties;
import com.lifey.chat.dto.ConversationListResponse;
import com.lifey.chat.dto.ConversationResponse;
import com.lifey.chat.dto.MessageListResponse;
import com.lifey.chat.dto.SendMessageRequest;
import com.lifey.chat.entity.ChatConversation;
import com.lifey.chat.entity.ChatMessage;
import com.lifey.chat.entity.ChatParticipant;
import com.lifey.chat.exception.ChatDisabledException;
import com.lifey.chat.exception.ConversationArchivedException;
import com.lifey.chat.exception.InvalidMessageBodyException;
import com.lifey.chat.repository.ChatConversationRepository;
import com.lifey.chat.repository.ChatMessageRepository;
import com.lifey.chat.repository.ChatParticipantRepository;
import com.lifey.chat.repository.ConversationUnreadCount;
import com.lifey.common.exception.ResourceNotFoundException;
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
    private final ChatParticipantRepository participantRepository;
    private final TrainerClientRepository trainerClientRepository;
    private final CurrentUserProvider currentUserProvider;
    private final ChatRateLimiter rateLimiter;
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

        List<ConversationResponse> items = conversations.stream()
                .map(conversation -> ChatMapper.toConversationResponse(
                        conversation,
                        viewerId,
                        previews.get(conversation.getLastMessageId()),
                        unreadByConversation.getOrDefault(conversation.getId(), 0L)))
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
    public SendMessageResult sendMessage(Long conversationId, SendMessageRequest request) {
        Long senderId = currentUserProvider.getUserId();
        ChatConversation conversation = requireParticipation(conversationId, senderId);

        if (!properties.enabled()) {
            throw new ChatDisabledException("Chat is temporarily unavailable");
        }
        if (conversation.getArchivedAt() != null) {
            throw new ConversationArchivedException("Conversation is archived: " + conversationId);
        }

        // Replay of an already-stored send: return it untouched and don't spend
        // rate-limit budget on a retry that isn't new traffic.
        Optional<ChatMessage> stored =
                messageRepository.findByConversationIdAndClientMessageId(conversationId, request.clientMessageId());
        if (stored.isPresent()) {
            return new SendMessageResult(ChatMapper.toMessageResponse(stored.get()), false);
        }

        String body = request.body().trim();
        if (body.isEmpty()) {
            throw new InvalidMessageBodyException("Message body must not be blank");
        }
        if (body.length() > properties.maxBodyLength()) {
            throw new InvalidMessageBodyException(
                    "Message body exceeds " + properties.maxBodyLength() + " characters");
        }

        rateLimiter.requireSendAllowance(senderId);

        Instant now = Instant.now();
        ChatMessage message = new ChatMessage();
        message.setConversation(conversation);
        message.setSender(senderOf(conversation, senderId));
        message.setBody(body);
        message.setClientMessageId(request.clientMessageId());
        message.setCreatedAt(now);
        messageRepository.save(message);

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
        participantRepository.findByConversationIdAndUserId(conversationId, callerId)
                .ifPresent(participant -> advanceCursor(participant, target, Instant.now()));
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
    }

    @Override
    public void archiveForPair(Long trainerId, Long clientId) {
        Instant now = Instant.now();
        conversationRepository.findByTrainerIdAndClientIdAndArchivedAtIsNull(trainerId, clientId)
                .forEach(conversation -> conversation.setArchivedAt(now));
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
        return ChatMapper.toConversationResponse(conversation, viewerId, lastMessage, unreadCount);
    }

    private static void advanceCursor(ChatParticipant participant, Long messageId, Instant now) {
        if (participant.getLastReadMessageId() != null && participant.getLastReadMessageId() >= messageId) {
            return;
        }
        participant.setLastReadMessageId(messageId);
        participant.setLastReadAt(now);
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

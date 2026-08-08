package com.lifey.chat.dto;

import java.util.List;

/** Always newest-first, whichever keyset direction was requested (§4.2). */
public record MessageListResponse(List<MessageResponse> items, boolean hasMore) {
}

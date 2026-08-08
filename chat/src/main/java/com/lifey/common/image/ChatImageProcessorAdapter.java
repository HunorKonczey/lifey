package com.lifey.common.image;

import com.lifey.chat.spi.ChatImageProcessor;
import org.springframework.stereotype.Component;

import java.awt.image.BufferedImage;
import java.io.InputStream;

/**
 * Backs the chat's {@link ChatImageProcessor} port with {@link ImageReencoder} —
 * the same pipeline as avatars and recipe photos, so an attachment gets the
 * same validation and the same EXIF stripping
 * (docs/chat/44-chat-service-extraction-plan.md §5.2).
 */
@Component
class ChatImageProcessorAdapter implements ChatImageProcessor {

    @Override
    public BufferedImage decode(InputStream input) {
        return ImageReencoder.decode(input);
    }

    @Override
    public byte[] boundedJpeg(BufferedImage source, int maxSide) {
        return ImageReencoder.boundedJpeg(source, maxSide);
    }

    @Override
    public String contentType() {
        return ImageReencoder.CONTENT_TYPE;
    }
}

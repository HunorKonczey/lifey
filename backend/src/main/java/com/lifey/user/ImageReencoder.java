package com.lifey.user;

import net.coobird.thumbnailator.Thumbnails;
import net.coobird.thumbnailator.geometry.Positions;

import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;

/**
 * Shared re-encode pipeline for anything that ends up in {@code user_avatars}:
 * decoding via ImageIO doubles as validation (malformed or non-image input
 * simply fails to decode), then the result is center-cropped to square and
 * resized to a fixed JPEG. Only decoded pixel data survives, so this also
 * strips all metadata (EXIF/GPS). Used by both direct uploads
 * (UserAvatarServiceImpl) and the Google avatar import (GoogleAvatarImportListener).
 */
public final class ImageReencoder {

    public static final String CONTENT_TYPE = "image/jpeg";

    private static final int TARGET_SIZE = 512;
    private static final float JPEG_QUALITY = 0.85f;

    private ImageReencoder() {
    }

    /**
     * @throws InvalidImageException if the input can't be decoded as an image
     */
    public static byte[] toSquareJpeg(InputStream input) {
        BufferedImage source;
        try {
            source = ImageIO.read(input);
        } catch (IOException e) {
            throw new InvalidImageException("Could not read the image");
        }
        if (source == null) {
            throw new InvalidImageException("Not a valid JPEG or PNG image");
        }

        int squareSide = Math.min(source.getWidth(), source.getHeight());
        try {
            ByteArrayOutputStream output = new ByteArrayOutputStream();
            Thumbnails.of(source)
                    .sourceRegion(Positions.CENTER, squareSide, squareSide)
                    .size(TARGET_SIZE, TARGET_SIZE)
                    .outputFormat("jpg")
                    .outputQuality(JPEG_QUALITY)
                    .toOutputStream(output);
            return output.toByteArray();
        } catch (IOException e) {
            throw new InvalidImageException("Could not process the image");
        }
    }
}

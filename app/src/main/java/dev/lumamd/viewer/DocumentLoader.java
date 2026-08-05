package dev.lumamd.viewer;

import android.content.ContentResolver;
import android.database.Cursor;
import android.net.Uri;
import android.provider.OpenableColumns;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;

final class DocumentLoader {
    private static final int MAX_FILE_BYTES = 5 * 1024 * 1024;

    static final class LoadedDocument {
        private final String content;
        private final String filename;
        private final long size;

        LoadedDocument(String content, String filename, long size) {
            this.content = content;
            this.filename = filename;
            this.size = size;
        }

        String getContent() {
            return content;
        }

        String getFilename() {
            return filename;
        }

        long getSize() {
            return size;
        }
    }

    private DocumentLoader() {
    }

    static LoadedDocument load(ContentResolver resolver, Uri uri) throws IOException {
        Metadata metadata = queryMetadata(resolver, uri);
        byte[] bytes = readBytes(resolver, uri);
        String filename = metadata.filename == null
                ? filenameFromUri(uri)
                : metadata.filename;
        long size = metadata.size >= 0 ? metadata.size : bytes.length;
        return new LoadedDocument(
                new String(bytes, StandardCharsets.UTF_8),
                filename,
                size);
    }

    private static byte[] readBytes(ContentResolver resolver, Uri uri) throws IOException {
        InputStream stream = resolver.openInputStream(uri);
        if (stream == null) {
            throw new IOException("The selected file cannot be opened.");
        }
        try (InputStream input = stream;
             ByteArrayOutputStream output = new ByteArrayOutputStream()) {
            byte[] buffer = new byte[16 * 1024];
            int total = 0;
            int read;
            while ((read = input.read(buffer)) != -1) {
                total += read;
                if (total > MAX_FILE_BYTES) {
                    throw new IOException("This file is larger than 5 MB.");
                }
                output.write(buffer, 0, read);
            }
            return output.toByteArray();
        }
    }

    private static Metadata queryMetadata(ContentResolver resolver, Uri uri) {
        String filename = null;
        long size = -1;
        try (Cursor cursor = resolver.query(
                uri,
                new String[]{OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE},
                null,
                null,
                null)) {
            if (cursor != null && cursor.moveToFirst()) {
                int nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME);
                int sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE);
                if (nameIndex >= 0 && !cursor.isNull(nameIndex)) {
                    filename = cursor.getString(nameIndex);
                }
                if (sizeIndex >= 0 && !cursor.isNull(sizeIndex)) {
                    size = cursor.getLong(sizeIndex);
                }
            }
        } catch (RuntimeException ignored) {
            // Some providers expose content but no metadata; the content stream remains valid.
        }
        return new Metadata(filename, size);
    }

    private static String filenameFromUri(Uri uri) {
        String segment = uri.getLastPathSegment();
        if (segment == null || segment.trim().isEmpty()) {
            return "Untitled.md";
        }
        int separator = segment.lastIndexOf('/');
        return separator >= 0 ? segment.substring(separator + 1) : segment;
    }

    private static final class Metadata {
        private final String filename;
        private final long size;

        private Metadata(String filename, long size) {
            this.filename = filename;
            this.size = size;
        }
    }
}

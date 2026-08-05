package dev.lumamd.viewer;

import android.content.ContentProvider;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.MatrixCursor;
import android.net.Uri;
import android.os.ParcelFileDescriptor;
import android.provider.OpenableColumns;

import java.io.File;
import java.io.FileOutputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.List;

public final class MarkdownShareProvider extends ContentProvider {
    static final String AUTHORITY = "dev.lumamd.viewer.share";
    static final String MIME_TYPE = "text/markdown";
    private static final String SHARE_DIRECTORY = "shared-markdown";

    static Uri write(Context context, String filename, String source) throws IOException {
        File directory = shareDirectory(context);
        if (!directory.isDirectory() && !directory.mkdirs()) {
            throw new IOException("Could not prepare the share directory.");
        }

        File file = new File(directory, markdownFilename(filename));
        try (FileOutputStream output = new FileOutputStream(file, false)) {
            output.write(source.getBytes(StandardCharsets.UTF_8));
        }

        return new Uri.Builder()
                .scheme(ContentResolver.SCHEME_CONTENT)
                .authority(AUTHORITY)
                .appendPath(file.getName())
                .build();
    }

    @Override
    public boolean onCreate() {
        return true;
    }

    @Override
    public String getType(Uri uri) {
        requireShareFile(uri);
        return MIME_TYPE;
    }

    @Override
    public Cursor query(
            Uri uri,
            String[] projection,
            String selection,
            String[] selectionArgs,
            String sortOrder) {
        File file = requireShareFile(uri);
        String[] columns = projection == null
                ? new String[]{OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE}
                : projection;
        MatrixCursor cursor = new MatrixCursor(columns, 1);
        MatrixCursor.RowBuilder row = cursor.newRow();
        for (String column : columns) {
            if (OpenableColumns.DISPLAY_NAME.equals(column)) {
                row.add(file.getName());
            } else if (OpenableColumns.SIZE.equals(column)) {
                row.add(file.length());
            } else {
                row.add(null);
            }
        }
        return cursor;
    }

    @Override
    public ParcelFileDescriptor openFile(Uri uri, String mode) throws FileNotFoundException {
        if (!"r".equals(mode)) {
            throw new FileNotFoundException("Shared Markdown files are read-only.");
        }
        File file = requireShareFile(uri);
        if (!file.isFile()) {
            throw new FileNotFoundException("Shared Markdown file does not exist.");
        }
        return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY);
    }

    @Override
    public Uri insert(Uri uri, ContentValues values) {
        throw new UnsupportedOperationException("Shared Markdown files are read-only.");
    }

    @Override
    public int delete(Uri uri, String selection, String[] selectionArgs) {
        throw new UnsupportedOperationException("Shared Markdown files are read-only.");
    }

    @Override
    public int update(
            Uri uri,
            ContentValues values,
            String selection,
            String[] selectionArgs) {
        throw new UnsupportedOperationException("Shared Markdown files are read-only.");
    }

    private static File shareDirectory(Context context) {
        return new File(context.getCacheDir(), SHARE_DIRECTORY);
    }

    private File requireShareFile(Uri uri) {
        if (!ContentResolver.SCHEME_CONTENT.equals(uri.getScheme())
                || !AUTHORITY.equals(uri.getAuthority())) {
            throw new IllegalArgumentException("Invalid shared Markdown URI.");
        }
        List<String> segments = uri.getPathSegments();
        if (segments.size() != 1) {
            throw new IllegalArgumentException("Invalid shared Markdown path.");
        }

        Context context = getContext();
        if (context == null) {
            throw new IllegalStateException("Share provider is unavailable.");
        }
        try {
            File directory = shareDirectory(context).getCanonicalFile();
            File file = new File(directory, segments.get(0)).getCanonicalFile();
            if (!directory.equals(file.getParentFile())) {
                throw new IllegalArgumentException("Invalid shared Markdown path.");
            }
            return file;
        } catch (IOException error) {
            throw new IllegalArgumentException("Invalid shared Markdown path.", error);
        }
    }

    private static String markdownFilename(String filename) {
        String value = filename == null ? "" : filename.trim();
        value = value.replace('/', '_').replace('\\', '_');
        StringBuilder safe = new StringBuilder(value.length());
        for (int index = 0; index < value.length(); index++) {
            char character = value.charAt(index);
            safe.append(Character.isISOControl(character) ? '_' : character);
        }

        value = safe.toString();
        if (value.isEmpty() || ".".equals(value) || "..".equals(value)) {
            value = "Shared note";
        }
        if (!value.toLowerCase(java.util.Locale.ROOT).endsWith(".md")) {
            int extension = value.lastIndexOf('.');
            if (extension > 0) {
                value = value.substring(0, extension);
            }
            value += ".md";
        }
        return value;
    }
}

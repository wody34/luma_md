package dev.lumamd.viewer;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.res.Configuration;
import android.graphics.Color;
import android.graphics.Insets;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.webkit.SafeBrowsingResponse;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;
import android.widget.Toast;

import dev.lumamd.viewer.core.AppPageBuilder;
import dev.lumamd.viewer.core.MarkdownDocument;
import dev.lumamd.viewer.core.MarkdownRenderer;
import dev.lumamd.viewer.core.SafeAreaInsets;
import dev.lumamd.viewer.core.WebNavigationPolicy;

import java.io.IOException;
import java.nio.charset.StandardCharsets;

public final class MainActivity extends Activity {
    private static final int OPEN_DOCUMENT_REQUEST = 1001;
    private static final String PREFS = "luma-preferences";
    private static final String PREF_THEME = "theme";
    private static final String PREF_TYPE_SCALE = "type-scale";
    private static final String PREF_RECENT_URI = "recent-uri";

    private final MarkdownRenderer renderer = new MarkdownRenderer();
    private final AppPageBuilder pageBuilder = new AppPageBuilder();

    private SharedPreferences preferences;
    private FrameLayout rootView;
    private WebView webView;
    private MarkdownDocument currentDocument;
    private String currentFilename;
    private long currentFileSize;
    private String theme;
    private int typeScale;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        preferences = getSharedPreferences(PREFS, MODE_PRIVATE);
        theme = preferences.getString(PREF_THEME, systemTheme());
        typeScale = preferences.getInt(PREF_TYPE_SCALE, 100);

        webView = createWebView();
        rootView = new FrameLayout(this);
        rootView.addView(webView, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT));
        setContentView(rootView);
        applySystemBarInsets(rootView);
        applyWindowTheme();

        if (!openFromIntent(getIntent())) {
            renderWelcome();
        }
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        if (!openFromIntent(intent)) {
            renderWelcome();
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode != OPEN_DOCUMENT_REQUEST || resultCode != RESULT_OK || data == null) {
            return;
        }
        Uri uri = data.getData();
        if (uri == null) {
            return;
        }
        int flags = data.getFlags()
                & (Intent.FLAG_GRANT_READ_URI_PERMISSION
                | Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
        try {
            getContentResolver().takePersistableUriPermission(
                    uri,
                    flags & Intent.FLAG_GRANT_READ_URI_PERMISSION);
        } catch (SecurityException ignored) {
            // A transient grant is still sufficient for this app session.
        }
        rememberAndOpen(uri);
    }

    @Override
    protected void onDestroy() {
        if (webView != null) {
            webView.stopLoading();
            webView.setWebViewClient(null);
            webView.destroy();
        }
        super.onDestroy();
    }

    private WebView createWebView() {
        WebView view = new WebView(this);
        WebSettings settings = view.getSettings();
        settings.setJavaScriptEnabled(false);
        settings.setDomStorageEnabled(false);
        settings.setAllowContentAccess(false);
        settings.setAllowFileAccess(false);
        settings.setSupportMultipleWindows(false);
        settings.setBuiltInZoomControls(false);
        settings.setDisplayZoomControls(false);
        settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        settings.setSafeBrowsingEnabled(true);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            settings.setAlgorithmicDarkeningAllowed(false);
        }
        view.removeJavascriptInterface("searchBoxJavaBridge_");
        view.removeJavascriptInterface("accessibility");
        view.removeJavascriptInterface("accessibilityTraversal");
        view.setBackgroundColor(Color.TRANSPARENT);
        view.setWebViewClient(new LumaWebViewClient());
        return view;
    }

    private void applySystemBarInsets(final View content) {
        View decorView = getWindow().getDecorView();
        decorView.setOnApplyWindowInsetsListener(new View.OnApplyWindowInsetsListener() {
            @Override
            public WindowInsets onApplyWindowInsets(View target, WindowInsets insets) {
                WindowInsets rootInsets = target.getRootWindowInsets();
                SafeAreaInsets safeInsets = resolveSafeAreaInsets(
                        rootInsets == null ? insets : rootInsets);
                if (content.getPaddingLeft() != safeInsets.getLeft()
                        || content.getPaddingTop() != safeInsets.getTop()
                        || content.getPaddingRight() != safeInsets.getRight()
                        || content.getPaddingBottom() != safeInsets.getBottom()) {
                    content.setPadding(
                            safeInsets.getLeft(),
                            safeInsets.getTop(),
                            safeInsets.getRight(),
                            safeInsets.getBottom());
                }
                return insets;
            }
        });
        decorView.requestApplyInsets();
    }

    private static SafeAreaInsets resolveSafeAreaInsets(WindowInsets insets) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            return SafeAreaInsets.none();
        }
        Insets systemBars = insets.getInsets(WindowInsets.Type.systemBars());
        Insets displayCutout = insets.getInsets(WindowInsets.Type.displayCutout());
        return SafeAreaInsets.resolve(
                systemBars.left,
                systemBars.top,
                systemBars.right,
                systemBars.bottom,
                displayCutout.left,
                displayCutout.top,
                displayCutout.right,
                displayCutout.bottom);
    }

    private boolean openFromIntent(Intent intent) {
        if (intent == null || !Intent.ACTION_VIEW.equals(intent.getAction())) {
            return false;
        }
        Uri uri = intent.getData();
        if (uri == null) {
            return false;
        }
        rememberAndOpen(uri);
        return true;
    }

    private void openDocumentPicker() {
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT)
                .addCategory(Intent.CATEGORY_OPENABLE)
                .setType("text/*")
                .putExtra(Intent.EXTRA_MIME_TYPES, new String[]{
                        "text/markdown",
                        "text/x-markdown",
                        "text/plain",
                        "application/octet-stream"
                })
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION
                        | Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
        try {
            startActivityForResult(intent, OPEN_DOCUMENT_REQUEST);
        } catch (ActivityNotFoundException error) {
            Toast.makeText(this, "No document picker is available.", Toast.LENGTH_LONG).show();
        }
    }

    private void rememberAndOpen(Uri uri) {
        preferences.edit().putString(PREF_RECENT_URI, uri.toString()).apply();
        openDocument(uri);
    }

    private void openRecent() {
        String stored = preferences.getString(PREF_RECENT_URI, "");
        if (stored == null || stored.isEmpty()) {
            renderWelcome();
            return;
        }
        openDocument(Uri.parse(stored));
    }

    private void openDocument(Uri uri) {
        try {
            DocumentLoader.LoadedDocument loaded = DocumentLoader.load(getContentResolver(), uri);
            currentDocument = renderer.render(loaded.getContent(), loaded.getFilename());
            currentFilename = loaded.getFilename();
            currentFileSize = loaded.getSize();
            renderCurrentDocument();
        } catch (IOException | SecurityException error) {
            currentDocument = null;
            Toast.makeText(
                    this,
                    "This note could not be opened. Check that the file is available and readable.",
                    Toast.LENGTH_LONG).show();
            renderWelcome();
        }
    }

    private void renderWelcome() {
        currentDocument = null;
        boolean hasRecent = preferences.contains(PREF_RECENT_URI);
        loadPage(pageBuilder.buildWelcome(theme, typeScale, hasRecent));
    }

    private void renderCurrentDocument() {
        if (currentDocument == null) {
            renderWelcome();
            return;
        }
        loadPage(pageBuilder.buildDocument(
                currentDocument,
                currentFilename,
                currentFileSize,
                theme,
                typeScale));
    }

    private void loadPage(String html) {
        webView.loadDataWithBaseURL(
                "https://luma.local/",
                html,
                "text/html",
                "UTF-8",
                null);
    }

    private void copyCurrentMarkdown() {
        if (currentDocument == null) {
            Toast.makeText(this, "Open a note before copying.", Toast.LENGTH_SHORT).show();
            return;
        }
        ClipboardManager clipboard = getSystemService(ClipboardManager.class);
        if (clipboard == null) {
            Toast.makeText(this, "Clipboard is unavailable.", Toast.LENGTH_SHORT).show();
            return;
        }
        clipboard.setPrimaryClip(ClipData.newPlainText(
                currentFilename,
                currentDocument.getSource()));
        Toast.makeText(this, "Markdown copied.", Toast.LENGTH_SHORT).show();
    }

    private void createMemoFromClipboard() {
        ClipboardManager clipboard = getSystemService(ClipboardManager.class);
        if (clipboard == null || !clipboard.hasPrimaryClip()) {
            Toast.makeText(this, "Clipboard has no text.", Toast.LENGTH_SHORT).show();
            return;
        }
        ClipData clip = clipboard.getPrimaryClip();
        if (clip == null || clip.getItemCount() == 0) {
            Toast.makeText(this, "Clipboard has no text.", Toast.LENGTH_SHORT).show();
            return;
        }
        CharSequence clipboardText = clip.getItemAt(0).coerceToText(this);
        if (clipboardText == null || clipboardText.toString().trim().isEmpty()) {
            Toast.makeText(this, "Clipboard has no text.", Toast.LENGTH_SHORT).show();
            return;
        }
        String source = clipboardText.toString();
        currentDocument = renderer.render(source, "Clipboard memo");
        currentFilename = "Clipboard memo.md";
        currentFileSize = source.getBytes(StandardCharsets.UTF_8).length;
        renderCurrentDocument();
    }

    private void shareCurrentMarkdown() {
        if (currentDocument == null) {
            Toast.makeText(this, "Open a note before sharing.", Toast.LENGTH_SHORT).show();
            return;
        }
        try {
            Uri shareUri = MarkdownShareProvider.write(
                    this,
                    currentFilename,
                    currentDocument.getSource());
            Intent share = new Intent(Intent.ACTION_SEND)
                    .setType("text/markdown")
                    .putExtra(Intent.EXTRA_STREAM, shareUri)
                    .putExtra(Intent.EXTRA_TITLE, currentFilename)
                    .putExtra(Intent.EXTRA_SUBJECT, currentFilename)
                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            share.setClipData(ClipData.newRawUri(currentFilename, shareUri));
            startActivity(Intent.createChooser(share, "Share Markdown"));
        } catch (IOException error) {
            Toast.makeText(this, "Could not prepare this note for sharing.", Toast.LENGTH_SHORT)
                    .show();
        } catch (ActivityNotFoundException error) {
            Toast.makeText(this, "No app can share this note.", Toast.LENGTH_SHORT).show();
        }
    }

    private void toggleTheme() {
        theme = "light".equals(theme) ? "dark" : "light";
        preferences.edit().putString(PREF_THEME, theme).apply();
        applyWindowTheme();
        renderCurrentDocument();
    }

    private void cycleTypeScale() {
        typeScale = typeScale == 92 ? 100 : typeScale == 100 ? 112 : 92;
        preferences.edit().putInt(PREF_TYPE_SCALE, typeScale).apply();
        renderCurrentDocument();
    }

    private void applyWindowTheme() {
        rootView.setBackgroundColor(Color.parseColor(
                "light".equals(theme) ? "#F3F0F7" : "#0E0D13"));
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            return;
        }
        WindowInsetsController controller = getWindow().getInsetsController();
        if (controller == null) {
            return;
        }
        int mask = WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS
                | WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS;
        controller.setSystemBarsAppearance("light".equals(theme) ? mask : 0, mask);
    }

    private String systemTheme() {
        int mode = getResources().getConfiguration().uiMode & Configuration.UI_MODE_NIGHT_MASK;
        return mode == Configuration.UI_MODE_NIGHT_YES ? "dark" : "light";
    }

    private void openExternal(Uri uri) {
        try {
            startActivity(new Intent(Intent.ACTION_VIEW, uri));
        } catch (ActivityNotFoundException error) {
            Toast.makeText(this, "No app can open this link.", Toast.LENGTH_SHORT).show();
        }
    }

    private final class LumaWebViewClient extends WebViewClient {
        @Override
        public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
            return handleUri(request.getUrl());
        }

        @Override
        public void onSafeBrowsingHit(
                WebView view,
                WebResourceRequest request,
                int threatType,
                SafeBrowsingResponse callback) {
            callback.backToSafety(true);
        }

        private boolean handleUri(Uri uri) {
            String scheme = uri.getScheme();
            WebNavigationPolicy.Decision decision =
                    WebNavigationPolicy.decide(scheme, uri.getHost());
            if (decision == WebNavigationPolicy.Decision.NATIVE_ACTION) {
                String action = uri.getHost();
                if ("open".equals(action)) {
                    openDocumentPicker();
                } else if ("recent".equals(action)) {
                    openRecent();
                } else if ("home".equals(action)) {
                    renderWelcome();
                } else if ("theme".equals(action)) {
                    toggleTheme();
                } else if ("type".equals(action)) {
                    cycleTypeScale();
                } else if ("copy".equals(action)) {
                    copyCurrentMarkdown();
                } else if ("paste".equals(action)) {
                    createMemoFromClipboard();
                } else if ("share".equals(action)) {
                    shareCurrentMarkdown();
                }
                return true;
            }
            if (decision == WebNavigationPolicy.Decision.OPEN_EXTERNAL) {
                openExternal(uri);
                return true;
            }
            return decision == WebNavigationPolicy.Decision.BLOCK;
        }
    }
}

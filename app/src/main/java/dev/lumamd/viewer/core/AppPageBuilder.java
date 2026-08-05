package dev.lumamd.viewer.core;

public final class AppPageBuilder {
    public String buildWelcome(String theme, int typeScale, boolean hasRecentDocument) {
        StringBuilder html = pageStart("Luma MD", theme, typeScale);
        html.append(topBar(theme))
                .append("<main class=\"welcome\">")
                .append("<section class=\"hero\" aria-labelledby=\"welcome-title\">")
                .append("<div class=\"eyebrow\"><span></span>LOCAL MARKDOWN READER</div>")
                .append("<h1 id=\"welcome-title\">Give every note a quiet place to land.</h1>")
                .append("<p class=\"hero-copy\">Open plain-text Markdown with focused typography, ")
                .append("useful structure, and no account between you and your words.</p>")
                .append("<div class=\"hero-actions\">")
                .append(primaryOpenButton("Open markdown"))
                .append(hasRecentDocument
                        ? "<a class=\"button ghost\" href=\"luma://recent\">Continue reading</a>"
                        : "")
                .append("<a class=\"button ghost\" href=\"luma://paste\" ")
                .append("aria-label=\"New memo from clipboard\">")
                .append(AppIcons.clipboard()).append("<span>Paste clipboard</span></a>")
                .append("</div></section>")
                .append("<section class=\"feature-panel\" aria-label=\"What makes Luma different\">")
                .append(feature(AppIcons.file(), "Local by design",
                        "Choose a file with Android’s secure picker. No broad storage access."))
                .append(feature(AppIcons.focus(), "Made for reading",
                        "A calm column, useful outline, and responsive type controls."))
                .append(feature(AppIcons.shield(), "Safer links",
                        "Markup is escaped and unknown URL schemes never become tappable."))
                .append("</section>")
                .append("<p class=\"privacy-note\">")
                .append(AppIcons.lock()).append("Nothing leaves your device.</p>")
                .append("</main>")
                .append(pageEnd());
        return html.toString();
    }

    public String buildDocument(
            MarkdownDocument document,
            String filename,
            long fileSize,
            String theme,
            int typeScale) {
        String safeFilename = InlineMarkdown.escape(filename);
        StringBuilder html = pageStart(document.getTitle() + " — Luma MD", theme, typeScale);
        html.append(topBar(theme))
                .append("<main id=\"reader\" class=\"reader-wrap\">")
                .append("<section class=\"document-head\">")
                .append("<div class=\"eyebrow\"><span></span>LOCAL FILE</div>")
                .append("<h1>").append(InlineMarkdown.escape(document.getTitle())).append("</h1>")
                .append("<div class=\"document-meta\">")
                .append(metadata(AppIcons.file(), safeFilename))
                .append(metadata(AppIcons.clock(), readingTime(document.getWordCount())))
                .append(metadata(AppIcons.storage(), formatSize(fileSize)))
                .append("</div></section>")
                .append("<article class=\"reader-surface")
                .append(document.isEmpty() ? " is-empty" : "")
                .append("\" aria-label=\"Markdown document\">")
                .append(document.getHtml())
                .append("</article>")
                .append("</main>")
                .append(outline(document))
                .append(actionsSheet(typeScale))
                .append(toolDock())
                .append(pageEnd());
        return html.toString();
    }

    private static StringBuilder pageStart(
            String title,
            String theme,
            int typeScale) {
        String safeTheme = "light".equals(theme) ? "light" : "dark";
        int safeScale = typeScale == 92 || typeScale == 112 ? typeScale : 100;
        return new StringBuilder(18000)
                .append("<!doctype html><html lang=\"en\" data-theme=\"")
                .append(safeTheme)
                .append("\"><head><meta charset=\"utf-8\">")
                .append("<meta name=\"viewport\" content=\"width=device-width,")
                .append("initial-scale=1,viewport-fit=cover\">")
                .append("<meta http-equiv=\"Content-Security-Policy\" content=\"")
                .append("default-src 'none'; script-src 'none'; connect-src 'none'; ")
                .append("img-src 'none'; font-src 'none'; media-src 'none'; ")
                .append("object-src 'none'; base-uri 'none'; form-action 'none'; ")
                .append("style-src 'unsafe-inline'\">")
                .append("<meta name=\"color-scheme\" content=\"dark light\">")
                .append("<title>").append(InlineMarkdown.escape(title)).append("</title>")
                .append("<style>").append(AppStyles.css()).append("</style></head>")
                .append("<body data-type-scale=\"").append(safeScale)
                .append("\" style=\"--type-scale:").append(safeScale / 100.0)
                .append("\">");
    }

    private static String pageEnd() {
        return "</body></html>";
    }

    private static String topBar(String theme) {
        String themeLabel = "light".equals(theme) ? "Use dark theme" : "Use light theme";
        return "<header class=\"topbar\"><div class=\"topbar-inner\">"
                + "<a class=\"brand\" href=\"luma://home\" aria-label=\"Luma MD home\">"
                + AppIcons.mark()
                + "<span class=\"brand-copy\"><strong>Luma MD</strong>"
                + "<small><i></i> Local reader</small></span></a>"
                + "<nav class=\"top-actions\" aria-label=\"App actions\">"
                + "<a class=\"icon-button\" href=\"luma://theme\" aria-label=\""
                + themeLabel + "\">" + AppIcons.theme(theme) + "</a>"
                + primaryOpenButton("Open")
                + "</nav></div></header>";
    }

    private static String primaryOpenButton(String label) {
        return "<a class=\"button primary\" href=\"luma://open\" aria-label=\"Open markdown\">"
                + AppIcons.folder() + "<span>" + label + "</span></a>";
    }

    private static String feature(String icon, String title, String copy) {
        return "<article class=\"feature\"><span class=\"feature-icon\">"
                + icon + "</span><div><h2>" + title + "</h2><p>" + copy
                + "</p></div></article>";
    }

    private static String metadata(String icon, String text) {
        return "<span>" + icon + text + "</span>";
    }

    private static String outline(MarkdownDocument document) {
        StringBuilder html = new StringBuilder()
                .append("<aside id=\"outline\" class=\"outline\" aria-label=\"Document outline\">")
                .append("<div class=\"outline-card\"><div class=\"outline-head\">")
                .append("<div><span class=\"eyebrow\">ON THIS PAGE</span><h2>Outline</h2></div>")
                .append("<a class=\"icon-button\" href=\"#reader\" aria-label=\"Close outline\">")
                .append(AppIcons.close()).append("</a></div><nav>");
        if (document.getHeadings().isEmpty()) {
            html.append("<p class=\"outline-empty\">Add headings to build an outline.</p>");
        } else {
            for (MarkdownDocument.Heading heading : document.getHeadings()) {
                html.append("<a class=\"level-").append(heading.getLevel())
                        .append("\" href=\"#").append(InlineMarkdown.escape(heading.getId()))
                        .append("\"><span></span>")
                        .append(InlineMarkdown.escape(heading.getText())).append("</a>");
            }
        }
        return html.append("</nav></div></aside>").toString();
    }

    private static String toolDock() {
        return "<nav class=\"tool-dock\" aria-label=\"Reading tools\">"
                + "<a href=\"luma://copy\" aria-label=\"Copy Markdown\">"
                + AppIcons.copy() + "<span>Copy</span></a>"
                + "<a href=\"luma://share\" aria-label=\"Share Markdown\">"
                + AppIcons.share() + "<span>Share</span></a>"
                + "<a href=\"#actions\" aria-label=\"Open reader actions\">"
                + AppIcons.actions() + "<span>Actions</span></a>"
                + "<a href=\"luma://open\" aria-label=\"Open markdown\">"
                + AppIcons.folder() + "<span>Open</span></a>"
                + "</nav>";
    }

    private static String actionsSheet(int typeScale) {
        String typeLabel = typeScale == 92 ? "Small" : typeScale == 112 ? "Large" : "Default";
        return "<aside id=\"actions\" class=\"actions-sheet\" aria-label=\"Reader actions\">"
                + "<div class=\"actions-card\"><div class=\"actions-head\">"
                + "<div><span class=\"eyebrow\">CURRENT NOTE</span><h2>Actions</h2></div>"
                + "<a class=\"icon-button\" href=\"#reader\" aria-label=\"Close reader actions\">"
                + AppIcons.close() + "</a></div><nav class=\"action-list\">"
                + actionItem(
                        "#outline",
                        "Outline",
                        "Open document outline",
                        "Jump to headings in the current note.",
                        AppIcons.outline())
                + actionItem(
                        "luma://type",
                        "Text size",
                        "Change text size",
                        "Current: " + typeLabel + ". Tap to change.",
                        AppIcons.type())
                + actionItem(
                        "luma://paste",
                        "New memo from clipboard",
                        "Render clipboard text as a temporary Markdown memo.",
                        AppIcons.clipboard())
                + "</nav></div></aside>";
    }

    private static String actionItem(String href, String title, String copy, String icon) {
        return actionItem(href, title, title, copy, icon);
    }

    private static String actionItem(
            String href,
            String title,
            String ariaLabel,
            String copy,
            String icon) {
        return "<a class=\"action-item\" href=\"" + href + "\" aria-label=\"" + ariaLabel + "\">"
                + "<span class=\"action-icon\">" + icon + "</span><span><strong>" + title
                + "</strong><small>" + copy + "</small></span></a>";
    }

    private static String readingTime(int words) {
        return Math.max(1, (words + 199) / 200) + " min read";
    }

    private static String formatSize(long bytes) {
        if (bytes < 1024) {
            return bytes + " B";
        }
        if (bytes < 1024 * 1024) {
            return String.format(java.util.Locale.ROOT, "%.1f KB", bytes / 1024.0);
        }
        return String.format(java.util.Locale.ROOT, "%.1f MB", bytes / (1024.0 * 1024.0));
    }
}

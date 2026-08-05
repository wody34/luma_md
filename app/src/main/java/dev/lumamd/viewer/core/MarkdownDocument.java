package dev.lumamd.viewer.core;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public final class MarkdownDocument {
    public static final class Heading {
        private final int level;
        private final String id;
        private final String text;

        public Heading(int level, String id, String text) {
            this.level = level;
            this.id = id;
            this.text = text;
        }

        public int getLevel() {
            return level;
        }

        public String getId() {
            return id;
        }

        public String getText() {
            return text;
        }
    }

    private final String html;
    private final String source;
    private final String title;
    private final int wordCount;
    private final boolean empty;
    private final List<Heading> headings;

    public MarkdownDocument(
            String html,
            String title,
            int wordCount,
            boolean empty,
            List<Heading> headings) {
        this(html, "", title, wordCount, empty, headings);
    }

    public MarkdownDocument(
            String html,
            String source,
            String title,
            int wordCount,
            boolean empty,
            List<Heading> headings) {
        this.html = html;
        this.source = source;
        this.title = title;
        this.wordCount = wordCount;
        this.empty = empty;
        this.headings = Collections.unmodifiableList(new ArrayList<Heading>(headings));
    }

    public String getHtml() {
        return html;
    }

    public String getSource() {
        return source;
    }

    public String getTitle() {
        return title;
    }

    public int getWordCount() {
        return wordCount;
    }

    public boolean isEmpty() {
        return empty;
    }

    public List<Heading> getHeadings() {
        return headings;
    }
}

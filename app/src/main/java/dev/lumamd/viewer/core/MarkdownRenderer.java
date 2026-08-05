package dev.lumamd.viewer.core;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public final class MarkdownRenderer {
    private static final Pattern HEADING = Pattern.compile("^(#{1,6})\\s+(.+?)\\s*#*\\s*$");
    private static final Pattern UNORDERED = Pattern.compile("^\\s*[-+*]\\s+(.+)$");
    private static final Pattern ORDERED = Pattern.compile("^\\s*\\d+[.)]\\s+(.+)$");
    private static final Pattern TASK = Pattern.compile("^\\[([ xX])\\]\\s+(.+)$");
    private static final Pattern TABLE_DIVIDER = Pattern.compile(
            "^\\s*\\|?\\s*:?-{3,}:?\\s*(\\|\\s*:?-{3,}:?\\s*)+\\|?\\s*$");
    private static final Pattern RULE = Pattern.compile("^\\s{0,3}((\\*\\s*){3,}|(-\\s*){3,}|(_\\s*){3,})$");

    public MarkdownDocument render(String markdown, String fallbackTitle) {
        String originalSource = markdown == null ? "" : markdown;
        String source = normalize(markdown);
        String safeFallback = cleanFallbackTitle(fallbackTitle);
        if (source.trim().isEmpty()) {
            return emptyDocument(safeFallback, originalSource);
        }
        FootnoteProcessor.Result footnotes = FootnoteProcessor.extract(source);
        source = footnotes.getSource();

        String[] lines = source.split("\\n", -1);
        StringBuilder html = new StringBuilder(source.length() + 256);
        List<MarkdownDocument.Heading> headings = new ArrayList<MarkdownDocument.Heading>();
        Map<String, Integer> slugs = new HashMap<String, Integer>();
        List<String> paragraph = new ArrayList<String>();
        String openList = "";
        String title = safeFallback;
        boolean titleFound = false;

        for (int index = 0; index < lines.length; index++) {
            String line = lines[index];

            if (hasOpenInlineMath(paragraph) && !line.trim().isEmpty()) {
                paragraph.add(line.trim());
                continue;
            }

            if (line.startsWith("```") || line.startsWith("~~~")) {
                flushParagraph(paragraph, html);
                openList = closeList(openList, html);
                char fence = line.charAt(0);
                int end = findFenceEnd(lines, index + 1, fence);
                String language = line.substring(3).trim();
                renderCodeBlock(lines, index + 1, end, language, html);
                index = end;
                continue;
            }

            if (line.trim().startsWith("$$")) {
                int mathEnd = findMathEnd(lines, index);
                if (mathEnd >= index) {
                    flushParagraph(paragraph, html);
                    openList = closeList(openList, html);
                    html.append(MathRenderer.renderBlock(mathExpression(lines, index, mathEnd)));
                    index = mathEnd;
                    continue;
                }
            }

            if (line.trim().isEmpty()) {
                flushParagraph(paragraph, html);
                openList = closeList(openList, html);
                continue;
            }

            Matcher heading = HEADING.matcher(line);
            if (heading.matches()) {
                flushParagraph(paragraph, html);
                openList = closeList(openList, html);
                int level = heading.group(1).length();
                String text = InlineMarkdown.plainText(heading.group(2));
                String id = uniqueSlug(text, slugs);
                headings.add(new MarkdownDocument.Heading(level, id, text));
                html.append("<h").append(level).append(" id=\"")
                        .append(InlineMarkdown.escape(id)).append("\">")
                        .append(InlineMarkdown.render(heading.group(2)))
                        .append("</h").append(level).append('>');
                if (!titleFound && level == 1) {
                    title = text;
                    titleFound = true;
                }
                continue;
            }

            if (index + 1 < lines.length
                    && line.indexOf('|') >= 0
                    && TABLE_DIVIDER.matcher(lines[index + 1]).matches()) {
                flushParagraph(paragraph, html);
                openList = closeList(openList, html);
                index = renderTable(lines, index, html);
                continue;
            }

            Matcher unordered = UNORDERED.matcher(line);
            Matcher ordered = ORDERED.matcher(line);
            if (unordered.matches() || ordered.matches()) {
                flushParagraph(paragraph, html);
                String targetList = unordered.matches() ? "ul" : "ol";
                if (!targetList.equals(openList)) {
                    openList = closeList(openList, html);
                    html.append('<').append(targetList).append('>');
                    openList = targetList;
                }
                renderListItem(unordered.matches() ? unordered.group(1) : ordered.group(1), html);
                continue;
            }

            if (line.startsWith(">")) {
                flushParagraph(paragraph, html);
                openList = closeList(openList, html);
                String quote = line.length() > 1 && line.charAt(1) == ' '
                        ? line.substring(2)
                        : line.substring(1);
                html.append("<blockquote><p>")
                        .append(InlineMarkdown.render(quote))
                        .append("</p></blockquote>");
                continue;
            }

            if (RULE.matcher(line).matches()) {
                flushParagraph(paragraph, html);
                openList = closeList(openList, html);
                html.append("<hr>");
                continue;
            }

            paragraph.add(line.trim());
        }

        flushParagraph(paragraph, html);
        closeList(openList, html);
        return new MarkdownDocument(
                footnotes.finish(html.toString()),
                originalSource,
                title,
                countWords(originalSource),
                false,
                headings);
    }

    private static MarkdownDocument emptyDocument(String title, String source) {
        String html = "<section class=\"empty-state\" role=\"status\">"
                + "<span class=\"empty-icon\" aria-hidden=\"true\"></span>"
                + "<h2>This file is empty</h2>"
                + "<p>Add some Markdown in your editor, then open it here again.</p>"
                + "<a class=\"button secondary\" href=\"luma://open\">Open another file</a>"
                + "</section>";
        return new MarkdownDocument(
                html,
                source,
                title,
                0,
                true,
                new ArrayList<MarkdownDocument.Heading>());
    }

    private static void flushParagraph(List<String> lines, StringBuilder html) {
        if (lines.isEmpty()) {
            return;
        }
        StringBuilder paragraph = new StringBuilder();
        for (int index = 0; index < lines.size(); index++) {
            if (index > 0) {
                paragraph.append(' ');
            }
            paragraph.append(lines.get(index));
        }
        html.append("<p>")
                .append(InlineMarkdown.render(paragraph.toString()))
                .append("</p>");
        lines.clear();
    }

    private static String closeList(String openList, StringBuilder html) {
        if (!openList.isEmpty()) {
            html.append("</").append(openList).append('>');
        }
        return "";
    }

    private static void renderListItem(String content, StringBuilder html) {
        Matcher task = TASK.matcher(content);
        if (!task.matches()) {
            html.append("<li>").append(InlineMarkdown.render(content)).append("</li>");
            return;
        }
        boolean done = !" ".equals(task.group(1));
        html.append("<li class=\"task");
        if (done) {
            html.append(" done");
        }
        html.append("\"><span class=\"checkbox\" aria-hidden=\"true\">");
        if (done) {
            html.append("✓");
        }
        html.append("</span><span>").append(InlineMarkdown.render(task.group(2)))
                .append("</span></li>");
    }

    private static int renderTable(String[] lines, int start, StringBuilder html) {
        List<String> headers = tableCells(lines[start]);
        html.append("<div class=\"table-scroll\"><table><thead><tr>");
        appendCells(headers, "th", html);
        html.append("</tr></thead><tbody>");
        int index = start + 2;
        while (index < lines.length
                && !lines[index].trim().isEmpty()
                && lines[index].indexOf('|') >= 0) {
            html.append("<tr>");
            appendCells(tableCells(lines[index]), "td", html);
            html.append("</tr>");
            index++;
        }
        html.append("</tbody></table></div>");
        return index - 1;
    }

    private static List<String> tableCells(String line) {
        String row = line.trim();
        if (row.startsWith("|")) {
            row = row.substring(1);
        }
        if (row.endsWith("|")) {
            row = row.substring(0, row.length() - 1);
        }
        String[] parts = row.split("\\|", -1);
        List<String> cells = new ArrayList<String>(parts.length);
        for (String part : parts) {
            cells.add(part.trim());
        }
        return cells;
    }

    private static void appendCells(List<String> cells, String tag, StringBuilder html) {
        for (String cell : cells) {
            html.append('<').append(tag).append('>')
                    .append(InlineMarkdown.render(cell))
                    .append("</").append(tag).append('>');
        }
    }

    private static int findFenceEnd(String[] lines, int start, char fence) {
        for (int index = start; index < lines.length; index++) {
            if (lines[index].length() >= 3
                    && lines[index].charAt(0) == fence
                    && lines[index].charAt(1) == fence
                    && lines[index].charAt(2) == fence) {
                return index;
            }
        }
        return lines.length;
    }

    private static int findMathEnd(String[] lines, int start) {
        String first = lines[start].trim();
        if (first.length() > 4 && first.endsWith("$$")) {
            return start;
        }
        if (!"$$".equals(first)) {
            return -1;
        }
        for (int index = start + 1; index < lines.length; index++) {
            if ("$$".equals(lines[index].trim())) {
                return index;
            }
        }
        return -1;
    }

    private static String mathExpression(String[] lines, int start, int end) {
        String first = lines[start].trim();
        if (start == end) {
            return first.substring(2, first.length() - 2).trim();
        }
        StringBuilder expression = new StringBuilder();
        for (int index = start + 1; index < end; index++) {
            if (expression.length() > 0) {
                expression.append(' ');
            }
            expression.append(lines[index].trim());
        }
        return expression.toString();
    }

    private static void renderCodeBlock(
            String[] lines,
            int start,
            int end,
            String language,
            StringBuilder html) {
        String canonicalLanguage = CodeHighlighter.canonicalLanguage(language);
        StringBuilder code = new StringBuilder();
        for (int index = start; index < end && index < lines.length; index++) {
            if (index > start) {
                code.append('\n');
            }
            code.append(lines[index]);
        }
        html.append("<pre");
        if (!language.isEmpty()) {
            html.append(" data-language=\"")
                    .append(InlineMarkdown.escape(language.toLowerCase(Locale.ROOT)))
                    .append("\"");
        }
        html.append("><code>");
        if (!canonicalLanguage.isEmpty()) {
            int insertion = html.length() - 1;
            html.insert(insertion, " class=\"language-" + canonicalLanguage + "\"");
        }
        html.append(CodeHighlighter.highlight(language, code.toString()));
        html.append("</code></pre>");
    }

    private static String uniqueSlug(String text, Map<String, Integer> slugs) {
        String base = text.toLowerCase(Locale.ROOT)
                .replaceAll("[^\\p{L}\\p{N}]+", "-")
                .replaceAll("(^-|-$)", "");
        if (base.isEmpty()) {
            base = "section";
        }
        Integer count = slugs.get(base);
        slugs.put(base, count == null ? 1 : count + 1);
        return count == null ? base : base + "-" + (count + 1);
    }

    private static int countWords(String source) {
        String plain = source.replaceAll("[#>*_~`|\\[\\]()!-]", " ").trim();
        return plain.isEmpty() ? 0 : plain.split("\\s+").length;
    }

    private static String normalize(String markdown) {
        return markdown == null ? "" : markdown.replace("\r\n", "\n").replace('\r', '\n');
    }

    private static boolean hasOpenInlineMath(List<String> lines) {
        int delimiterCount = 0;
        for (String line : lines) {
            char previous = '\0';
            for (int index = 0; index < line.length(); index++) {
                char character = line.charAt(index);
                if (character == '$' && previous != '\\') {
                    delimiterCount++;
                }
                previous = character;
            }
        }
        return delimiterCount % 2 != 0;
    }

    private static String cleanFallbackTitle(String fallbackTitle) {
        String value = fallbackTitle == null || fallbackTitle.trim().isEmpty()
                ? "Untitled note"
                : fallbackTitle.trim();
        return value.replaceFirst("(?i)\\.(md|markdown|txt)$", "");
    }
}

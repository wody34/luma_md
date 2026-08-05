package dev.lumamd.viewer.core;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

final class FootnoteProcessor {
    private static final Pattern DEFINITION = Pattern.compile(
            "^\\s{0,3}\\[\\^([^]]+)]\\s*:\\s*(.*)$");
    private static final char TOKEN = '\u0005';

    private FootnoteProcessor() {
    }

    static Result extract(String source) {
        String[] lines = source.split("\\n", -1);
        Map<String, String> definitions = collectDefinitions(lines);
        Map<String, Integer> numbers = new LinkedHashMap<String, Integer>();
        Map<String, Integer> occurrences = new LinkedHashMap<String, Integer>();
        List<Reference> references = new ArrayList<Reference>();

        boolean inFence = false;
        for (int index = 0; index < lines.length; index++) {
            String trimmed = lines[index].trim();
            if (isFence(trimmed)) {
                inFence = !inFence;
                continue;
            }
            if (!inFence && !DEFINITION.matcher(lines[index]).matches()) {
                lines[index] = replaceReferences(
                        lines[index],
                        definitions,
                        numbers,
                        occurrences,
                        references);
            } else if (!inFence) {
                lines[index] = "";
            }
        }
        return new Result(join(lines), definitions, numbers, occurrences, references);
    }

    private static Map<String, String> collectDefinitions(String[] lines) {
        Map<String, String> definitions = new LinkedHashMap<String, String>();
        boolean inFence = false;
        for (String line : lines) {
            String trimmed = line.trim();
            if (isFence(trimmed)) {
                inFence = !inFence;
                continue;
            }
            if (inFence) {
                continue;
            }
            Matcher definition = DEFINITION.matcher(line);
            if (definition.matches() && !definitions.containsKey(definition.group(1))) {
                definitions.put(definition.group(1), definition.group(2));
            }
        }
        return definitions;
    }

    private static String replaceReferences(
            String line,
            Map<String, String> definitions,
            Map<String, Integer> numbers,
            Map<String, Integer> occurrences,
            List<Reference> references) {
        StringBuilder output = new StringBuilder(line.length());
        boolean inCode = false;
        int cursor = 0;
        while (cursor < line.length()) {
            char current = line.charAt(cursor);
            if (current == '`') {
                inCode = !inCode;
                output.append(current);
                cursor++;
                continue;
            }
            if (!inCode && current == '[' && cursor + 3 < line.length()
                    && line.charAt(cursor + 1) == '^') {
                int end = line.indexOf(']', cursor + 2);
                if (end > cursor + 2) {
                    String key = line.substring(cursor + 2, end);
                    if (definitions.containsKey(key)) {
                        Integer number = numbers.get(key);
                        if (number == null) {
                            number = numbers.size() + 1;
                            numbers.put(key, number);
                        }
                        int occurrence = occurrences.containsKey(key)
                                ? occurrences.get(key) + 1
                                : 1;
                        occurrences.put(key, occurrence);
                        Reference reference = new Reference(
                                key,
                                number,
                                occurrence,
                                references.size());
                        references.add(reference);
                        output.append(TOKEN).append(reference.tokenIndex).append(TOKEN);
                        cursor = end + 1;
                        continue;
                    }
                }
            }
            output.append(current);
            cursor++;
        }
        return output.toString();
    }

    private static boolean isFence(String line) {
        return line.startsWith("```") || line.startsWith("~~~");
    }

    private static String join(String[] lines) {
        StringBuilder output = new StringBuilder();
        for (int index = 0; index < lines.length; index++) {
            if (index > 0) {
                output.append('\n');
            }
            output.append(lines[index]);
        }
        return output.toString();
    }

    private static String safeId(String key) {
        String value = key.toLowerCase(Locale.ROOT)
                .replaceAll("[^\\p{L}\\p{N}_-]+", "-")
                .replaceAll("(^-|-$)", "");
        return value.isEmpty() ? "note" : value;
    }

    static final class Result {
        private final String source;
        private final Map<String, String> definitions;
        private final Map<String, Integer> numbers;
        private final Map<String, Integer> occurrences;
        private final List<Reference> references;

        private Result(
                String source,
                Map<String, String> definitions,
                Map<String, Integer> numbers,
                Map<String, Integer> occurrences,
                List<Reference> references) {
            this.source = source;
            this.definitions = definitions;
            this.numbers = numbers;
            this.occurrences = occurrences;
            this.references = references;
        }

        String getSource() {
            return source;
        }

        String finish(String documentHtml) {
            String html = documentHtml;
            for (Reference reference : references) {
                html = html.replace(
                        TOKEN + String.valueOf(reference.tokenIndex) + TOKEN,
                        referenceHtml(reference));
            }
            return html + sectionHtml();
        }

        private String referenceHtml(Reference reference) {
            String id = safeId(reference.key);
            String referenceId = "fnref-" + id
                    + (reference.occurrence > 1 ? "-" + reference.occurrence : "");
            return "<sup class=\"footnote-ref\"><a id=\"" + InlineMarkdown.escape(referenceId)
                    + "\" href=\"#fn-" + InlineMarkdown.escape(id)
                    + "\" aria-label=\"Footnote " + reference.number + "\">"
                    + reference.number + "</a></sup>";
        }

        private String sectionHtml() {
            if (numbers.isEmpty()) {
                return "";
            }
            StringBuilder html = new StringBuilder()
                    .append("<section class=\"footnotes\" aria-label=\"Footnotes\">")
                    .append("<hr><ol>");
            for (Map.Entry<String, Integer> numbered : numbers.entrySet()) {
                String key = numbered.getKey();
                String id = safeId(key);
                html.append("<li id=\"fn-").append(InlineMarkdown.escape(id)).append("\">")
                        .append("<span class=\"footnote-content\">")
                        .append(InlineMarkdown.render(definitions.get(key)))
                        .append("</span><span class=\"footnote-backlinks\">");
                int count = occurrences.get(key);
                for (int occurrence = 1; occurrence <= count; occurrence++) {
                    String referenceId = "fnref-" + id
                            + (occurrence > 1 ? "-" + occurrence : "");
                    html.append("<a class=\"footnote-backref\" href=\"#")
                            .append(InlineMarkdown.escape(referenceId))
                            .append("\" aria-label=\"Back to footnote reference ")
                            .append(occurrence).append("\">↩</a>");
                }
                html.append("</span></li>");
            }
            return html.append("</ol></section>").toString();
        }
    }

    private static final class Reference {
        private final String key;
        private final int number;
        private final int occurrence;
        private final int tokenIndex;

        private Reference(String key, int number, int occurrence, int tokenIndex) {
            this.key = key;
            this.number = number;
            this.occurrence = occurrence;
            this.tokenIndex = tokenIndex;
        }
    }
}

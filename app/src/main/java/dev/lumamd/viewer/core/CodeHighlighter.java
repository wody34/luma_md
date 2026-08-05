package dev.lumamd.viewer.core;

import java.util.Arrays;
import java.util.Collections;
import java.util.HashSet;
import java.util.Locale;
import java.util.Set;

final class CodeHighlighter {
    private static final Set<String> JVM_KEYWORDS = words(
            "abstract actual annotation as break by catch class companion const constructor "
                    + "continue data do else enum expect extends false final finally for fun if "
                    + "implements import in infix inline interface internal is lateinit native new "
                    + "object open operator out override package private protected public reified "
                    + "return sealed static strictfp super suspend synchronized this throw throws "
                    + "transient true try typealias typeof val var void volatile when while");
    private static final Set<String> SCRIPT_KEYWORDS = words(
            "async await break case catch class const continue debugger default delete do else "
                    + "export extends finally for from function get if implements import in "
                    + "instanceof interface let new of package private protected public return "
                    + "set static super switch this throw try typeof var void while with yield");
    private static final Set<String> PYTHON_KEYWORDS = words(
            "and as assert async await break class continue def del elif else except False finally "
                    + "for from global if import in is lambda None nonlocal not or pass raise "
                    + "return True try while with yield");
    private static final Set<String> BASH_KEYWORDS = words(
            "case do done elif else esac fi for function if in select then time until while");
    private static final Set<String> LITERALS = words(
            "true false null undefined NaN Infinity None True False");

    private CodeHighlighter() {
    }

    static String canonicalLanguage(String language) {
        String value = language == null ? "" : language.trim().toLowerCase(Locale.ROOT);
        if ("kt".equals(value)) {
            return "kotlin";
        }
        if ("js".equals(value)) {
            return "javascript";
        }
        if ("ts".equals(value) || "tsx".equals(value)) {
            return "typescript";
        }
        if ("py".equals(value)) {
            return "python";
        }
        if ("sh".equals(value) || "shell".equals(value) || "zsh".equals(value)) {
            return "bash";
        }
        if ("html".equals(value) || "svg".equals(value)) {
            return "xml";
        }
        if ("md".equals(value)) {
            return "markdown";
        }
        switch (value) {
            case "kotlin":
            case "java":
            case "javascript":
            case "typescript":
            case "python":
            case "bash":
            case "json":
            case "xml":
            case "css":
            case "markdown":
                return value;
            default:
                return "";
        }
    }

    static String highlight(String language, String source) {
        String canonical = canonicalLanguage(language);
        if (canonical.isEmpty()) {
            return InlineMarkdown.escape(source);
        }
        if ("xml".equals(canonical)) {
            return highlightMarkup(source);
        }
        if ("markdown".equals(canonical)) {
            return highlightMarkdown(source);
        }
        return highlightCode(canonical, source);
    }

    private static String highlightCode(String language, String source) {
        StringBuilder html = new StringBuilder(source.length() * 2);
        int cursor = 0;
        while (cursor < source.length()) {
            char current = source.charAt(cursor);
            if (startsLineComment(language, source, cursor)) {
                int end = lineEnd(source, cursor);
                html.append(span("comment", source.substring(cursor, end)));
                cursor = end;
            } else if (source.startsWith("/*", cursor) && supportsSlashComments(language)) {
                int end = source.indexOf("*/", cursor + 2);
                end = end < 0 ? source.length() : end + 2;
                html.append(span("comment", source.substring(cursor, end)));
                cursor = end;
            } else if (current == '"' || current == '\''
                    || (current == '`' && supportsBackticks(language))) {
                int end = quotedEnd(source, cursor, current);
                html.append(span("string", source.substring(cursor, end)));
                cursor = end;
            } else if (Character.isDigit(current)) {
                int end = cursor + 1;
                while (end < source.length()
                        && (Character.isDigit(source.charAt(end))
                        || ".xabcdefABCDEF_".indexOf(source.charAt(end)) >= 0)) {
                    end++;
                }
                html.append(span("number", source.substring(cursor, end)));
                cursor = end;
            } else if (Character.isJavaIdentifierStart(current)) {
                int end = cursor + 1;
                while (end < source.length()
                        && Character.isJavaIdentifierPart(source.charAt(end))) {
                    end++;
                }
                String word = source.substring(cursor, end);
                html.append(highlightWord(language, word));
                cursor = end;
            } else if (current == '$' && "bash".equals(language)) {
                int end = cursor + 1;
                while (end < source.length()
                        && (Character.isLetterOrDigit(source.charAt(end))
                        || source.charAt(end) == '_')) {
                    end++;
                }
                html.append(span("variable", source.substring(cursor, end)));
                cursor = end;
            } else {
                html.append(InlineMarkdown.escape(String.valueOf(current)));
                cursor++;
            }
        }
        return html.toString();
    }

    private static String highlightWord(String language, String word) {
        if (LITERALS.contains(word)) {
            return span("literal", word);
        }
        Set<String> keywords;
        if ("kotlin".equals(language) || "java".equals(language)) {
            keywords = JVM_KEYWORDS;
        } else if ("javascript".equals(language) || "typescript".equals(language)) {
            keywords = SCRIPT_KEYWORDS;
        } else if ("python".equals(language)) {
            keywords = PYTHON_KEYWORDS;
        } else if ("bash".equals(language)) {
            keywords = BASH_KEYWORDS;
        } else {
            keywords = Collections.emptySet();
        }
        if (keywords.contains(word)) {
            return span("keyword", word);
        }
        if (!word.isEmpty() && Character.isUpperCase(word.charAt(0))) {
            return span("type", word);
        }
        return InlineMarkdown.escape(word);
    }

    private static String highlightMarkup(String source) {
        StringBuilder html = new StringBuilder(source.length() * 2);
        int cursor = 0;
        while (cursor < source.length()) {
            if (source.startsWith("<!--", cursor)) {
                int end = source.indexOf("-->", cursor + 4);
                end = end < 0 ? source.length() : end + 3;
                html.append(span("comment", source.substring(cursor, end)));
                cursor = end;
            } else if (source.charAt(cursor) == '<') {
                int end = source.indexOf('>', cursor + 1);
                end = end < 0 ? source.length() : end + 1;
                html.append(span("keyword", source.substring(cursor, end)));
                cursor = end;
            } else {
                int end = source.indexOf('<', cursor);
                end = end < 0 ? source.length() : end;
                html.append(InlineMarkdown.escape(source.substring(cursor, end)));
                cursor = end;
            }
        }
        return html.toString();
    }

    private static String highlightMarkdown(String source) {
        StringBuilder html = new StringBuilder(source.length() * 2);
        String[] lines = source.split("\\n", -1);
        for (int index = 0; index < lines.length; index++) {
            String line = lines[index];
            int markerEnd = markdownMarkerEnd(line);
            if (markerEnd > 0) {
                html.append(span("keyword", line.substring(0, markerEnd)))
                        .append(InlineMarkdown.escape(line.substring(markerEnd)));
            } else {
                html.append(InlineMarkdown.escape(line));
            }
            if (index < lines.length - 1) {
                html.append('\n');
            }
        }
        return html.toString();
    }

    private static int markdownMarkerEnd(String line) {
        if (line.startsWith("#")) {
            int end = 0;
            while (end < line.length() && line.charAt(end) == '#') {
                end++;
            }
            return end < line.length() && line.charAt(end) == ' ' ? end : 0;
        }
        return line.startsWith("> ") || line.startsWith("- ") || line.startsWith("* ")
                ? 1 : 0;
    }

    private static boolean startsLineComment(String language, String source, int cursor) {
        if (supportsSlashComments(language) && source.startsWith("//", cursor)) {
            return true;
        }
        return ("python".equals(language) || "bash".equals(language))
                && source.charAt(cursor) == '#';
    }

    private static boolean supportsSlashComments(String language) {
        return "kotlin".equals(language)
                || "java".equals(language)
                || "javascript".equals(language)
                || "typescript".equals(language)
                || "css".equals(language);
    }

    private static boolean supportsBackticks(String language) {
        return "javascript".equals(language) || "typescript".equals(language);
    }

    private static int lineEnd(String source, int start) {
        int end = source.indexOf('\n', start);
        return end < 0 ? source.length() : end;
    }

    private static int quotedEnd(String source, int start, char quote) {
        int cursor = start + 1;
        while (cursor < source.length()) {
            if (source.charAt(cursor) == '\\') {
                cursor += 2;
            } else if (source.charAt(cursor) == quote) {
                return cursor + 1;
            } else {
                cursor++;
            }
        }
        return source.length();
    }

    private static String span(String kind, String value) {
        return "<span class=\"tok-" + kind + "\">"
                + InlineMarkdown.escape(value) + "</span>";
    }

    private static Set<String> words(String source) {
        return Collections.unmodifiableSet(
                new HashSet<String>(Arrays.asList(source.split(" "))));
    }
}

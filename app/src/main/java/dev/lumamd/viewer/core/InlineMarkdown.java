package dev.lumamd.viewer.core;

import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

final class InlineMarkdown {
    private static final Pattern CODE = Pattern.compile("`([^`\\n]+)`");
    private static final Pattern MATH = Pattern.compile("(?<!\\\\)\\$([^$\\n]+)\\$");
    private static final Pattern IMAGE = Pattern.compile("!\\[([^]]*)]\\(([^\\s)]+)\\)");
    private static final Pattern LINK = Pattern.compile("\\[([^]]+)]\\(([^\\s)]+)\\)");
    private static final Pattern STRONG_ASTERISK = Pattern.compile("\\*\\*([^*\\n]+)\\*\\*");
    private static final Pattern STRONG_UNDERSCORE = Pattern.compile("__([^_\\n]+)__");
    private static final Pattern EMPHASIS_ASTERISK = Pattern.compile("(?<!\\*)\\*([^*\\n]+)\\*(?!\\*)");
    private static final Pattern EMPHASIS_UNDERSCORE = Pattern.compile(
            "(?<![\\p{L}\\p{N}_])_([^_\\n]+)_(?![\\p{L}\\p{N}_])");
    private static final Pattern STRIKE = Pattern.compile("~~([^~\\n]+)~~");

    private InlineMarkdown() {
    }

    static String render(String source) {
        List<String> fragments = new ArrayList<String>();
        Matcher code = CODE.matcher(source);
        StringBuffer protectedSource = new StringBuffer();
        while (code.find()) {
            String token = "\u0007" + fragments.size() + "\u0007";
            fragments.add("<code>" + escape(code.group(1)) + "</code>");
            code.appendReplacement(protectedSource, Matcher.quoteReplacement(token));
        }
        code.appendTail(protectedSource);

        Matcher math = MATH.matcher(protectedSource.toString());
        StringBuffer protectedMath = new StringBuffer();
        while (math.find()) {
            String token = "\u0007" + fragments.size() + "\u0007";
            fragments.add(MathRenderer.renderInline(math.group(1)));
            math.appendReplacement(protectedMath, Matcher.quoteReplacement(token));
        }
        math.appendTail(protectedMath);

        String value = escape(protectedMath.toString());
        value = replaceImages(value);
        value = replaceLinks(value);
        value = replace(value, STRONG_ASTERISK, "<strong>$1</strong>");
        value = replace(value, STRONG_UNDERSCORE, "<strong>$1</strong>");
        value = replace(value, EMPHASIS_ASTERISK, "<em>$1</em>");
        value = replace(value, EMPHASIS_UNDERSCORE, "<em>$1</em>");
        value = replace(value, STRIKE, "<del>$1</del>");
        for (int index = 0; index < fragments.size(); index++) {
            value = value.replace("\u0007" + index + "\u0007", fragments.get(index));
        }
        return value;
    }

    static String plainText(String source) {
        return source
                .replaceAll("!\\[([^]]*)]\\([^)]*\\)", "$1")
                .replaceAll("\\[([^]]+)]\\([^)]*\\)", "$1")
                .replaceAll("[*_~`]", "")
                .trim();
    }

    static String escape(String value) {
        return value
                .replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;")
                .replace("'", "&#39;");
    }

    private static String replaceImages(String source) {
        Matcher matcher = IMAGE.matcher(source);
        StringBuffer output = new StringBuffer();
        while (matcher.find()) {
            String alt = matcher.group(1);
            String destination = matcher.group(2);
            String replacement = isSafeWebUrl(destination)
                    ? "<img src=\"" + destination + "\" alt=\"" + alt + "\" loading=\"lazy\">"
                    : "<span class=\"image-alt\">[" + alt + "]</span>";
            matcher.appendReplacement(output, Matcher.quoteReplacement(replacement));
        }
        matcher.appendTail(output);
        return output.toString();
    }

    private static String replaceLinks(String source) {
        Matcher matcher = LINK.matcher(source);
        StringBuffer output = new StringBuffer();
        while (matcher.find()) {
            String label = matcher.group(1);
            String destination = matcher.group(2);
            String replacement;
            if (isSafeLink(destination)) {
                String external = destination.startsWith("#")
                        ? ""
                        : " target=\"_blank\" rel=\"noopener noreferrer\"";
                replacement = "<a href=\"" + destination + "\"" + external + ">"
                        + label + "</a>";
            } else {
                replacement = "<span class=\"unsafe-link\">" + label + "</span>";
            }
            matcher.appendReplacement(output, Matcher.quoteReplacement(replacement));
        }
        matcher.appendTail(output);
        return output.toString();
    }

    private static String replace(String source, Pattern pattern, String replacement) {
        return pattern.matcher(source).replaceAll(replacement);
    }

    private static boolean isSafeLink(String destination) {
        return destination.startsWith("#")
                || isSafeWebUrl(destination)
                || destination.startsWith("mailto:");
    }

    private static boolean isSafeWebUrl(String destination) {
        return destination.startsWith("https://") || destination.startsWith("http://");
    }
}

package dev.lumamd.viewer.core;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

final class MathMLParser {
    private static final int MAXIMUM_DEPTH = 64;
    private static final int MAXIMUM_NODE_COUNT = 4096;

    private enum Terminator {
        END,
        GROUP,
        INDEX,
        RIGHT,
        ENVIRONMENT_CELL
    }

    private static final Map<String, String> SYMBOLS;
    private static final Set<String> IDENTIFIERS;
    private static final Set<String> LIMIT_OPERATORS;
    private static final Set<String> NAMED_OPERATORS;

    static {
        Map<String, String> symbols = new HashMap<String, String>();
        symbols.put("alpha", "α");
        symbols.put("beta", "β");
        symbols.put("gamma", "γ");
        symbols.put("delta", "δ");
        symbols.put("theta", "θ");
        symbols.put("lambda", "λ");
        symbols.put("mu", "μ");
        symbols.put("pi", "π");
        symbols.put("sigma", "σ");
        symbols.put("phi", "φ");
        symbols.put("omega", "ω");
        symbols.put("Delta", "Δ");
        symbols.put("Lambda", "Λ");
        symbols.put("Sigma", "Σ");
        symbols.put("Omega", "Ω");
        symbols.put("pm", "±");
        symbols.put("times", "×");
        symbols.put("cdot", "·");
        symbols.put("le", "≤");
        symbols.put("leq", "≤");
        symbols.put("ge", "≥");
        symbols.put("geq", "≥");
        symbols.put("neq", "≠");
        symbols.put("approx", "≈");
        symbols.put("infty", "∞");
        symbols.put("rightarrow", "→");
        symbols.put("leftarrow", "←");
        symbols.put("to", "→");
        symbols.put("in", "∈");
        symbols.put("dots", "…");
        symbols.put("star", "⋆");
        symbols.put("mid", "|");
        symbols.put("perp", "⊥");
        symbols.put("top", "⊤");
        symbols.put("partial", "∂");
        symbols.put("nabla", "∇");
        symbols.put("sim", "∼");
        symbols.put("vert", "|");
        symbols.put("Vert", "∥");
        symbols.put("lvert", "|");
        symbols.put("rvert", "|");
        symbols.put("lVert", "∥");
        symbols.put("rVert", "∥");
        SYMBOLS = Collections.unmodifiableMap(symbols);

        Set<String> identifiers = new HashSet<String>();
        Collections.addAll(
                identifiers,
                "alpha", "beta", "gamma", "delta", "theta", "lambda", "mu", "pi",
                "sigma", "phi", "omega", "Delta", "Lambda", "Sigma", "Omega",
                "partial", "nabla");
        IDENTIFIERS = Collections.unmodifiableSet(identifiers);

        Set<String> limits = new HashSet<String>();
        Collections.addAll(limits, "sum", "prod", "int");
        LIMIT_OPERATORS = Collections.unmodifiableSet(limits);

        Set<String> operators = new HashSet<String>();
        Collections.addAll(
                operators,
                "sin", "cos", "tan", "log", "ln", "exp", "max", "min", "lim");
        NAMED_OPERATORS = Collections.unmodifiableSet(operators);
    }

    private final String source;
    private int cursor;
    private int depth;
    private int nodeCount;

    MathMLParser(String source) {
        this.source = source;
    }

    String render() {
        try {
            MathMLNode node = sequence(Terminator.END);
            skipSpaces();
            if (cursor != source.length()) {
                throw new ParseException();
            }
            return node.render();
        } catch (ParseException error) {
            return MathMLNode.text(source).render();
        }
    }

    private MathMLNode sequence(Terminator terminator) throws ParseException {
        List<MathMLNode> nodes = new ArrayList<MathMLNode>();
        while (cursor < source.length()) {
            skipSpaces();
            if (cursor >= source.length() || isAt(terminator)) {
                break;
            }
            nodes.add(decoratedAtom());
        }
        return MathMLNode.row(nodes);
    }

    private MathMLNode decoratedAtom() throws ParseException {
        MathMLNode base = atom();
        MathMLNode subscript = null;
        MathMLNode superscript = null;
        while (cursor < source.length()) {
            skipSpaces();
            if (take("_")) {
                if (subscript != null) {
                    throw new ParseException();
                }
                subscript = argument();
            } else if (take("^")) {
                if (superscript != null) {
                    throw new ParseException();
                }
                superscript = argument();
            } else {
                break;
            }
        }
        if (subscript != null && superscript != null) {
            return base.hasLimits()
                    ? MathMLNode.underOver(base, subscript, superscript)
                    : MathMLNode.subSuperscript(base, subscript, superscript);
        }
        if (subscript != null) {
            return base.hasLimits()
                    ? MathMLNode.under(base, subscript)
                    : MathMLNode.subscript(base, subscript);
        }
        if (superscript != null) {
            return base.hasLimits()
                    ? MathMLNode.over(base, superscript)
                    : MathMLNode.superscript(base, superscript);
        }
        return base;
    }

    private MathMLNode atom() throws ParseException {
        if (depth >= MAXIMUM_DEPTH || nodeCount >= MAXIMUM_NODE_COUNT) {
            throw new ParseException();
        }
        depth++;
        nodeCount++;
        try {
            skipSpaces();
            if (cursor >= source.length()) {
                throw new ParseException();
            }
            char current = source.charAt(cursor);
            int codePoint = source.codePointAt(cursor);
            if (current == '\\') {
                return command();
            }
            if (current == '{') {
                cursor++;
                MathMLNode group = sequence(Terminator.GROUP);
                require("}");
                return group;
            }
            if (Character.isDigit(codePoint) || current == '.') {
                return number();
            }
            if (Character.isLetter(codePoint)) {
                cursor += Character.charCount(codePoint);
                return MathMLNode.identifier(new String(Character.toChars(codePoint)));
            }
            if ("+-=<>|,;:/()[]&".indexOf(current) >= 0) {
                cursor++;
                return MathMLNode.operator(String.valueOf(current));
            }
            if (current == '^' || current == '_' || current == '}') {
                throw new ParseException();
            }
            cursor += Character.charCount(codePoint);
            return MathMLNode.operator(new String(Character.toChars(codePoint)));
        } finally {
            depth--;
        }
    }

    private MathMLNode number() {
        int start = cursor;
        boolean foundDecimal = false;
        while (cursor < source.length()) {
            int codePoint = source.codePointAt(cursor);
            if (Character.isDigit(codePoint)) {
                cursor += Character.charCount(codePoint);
            } else if (codePoint == '.' && !foundDecimal) {
                foundDecimal = true;
                cursor++;
            } else {
                break;
            }
        }
        return MathMLNode.number(source.substring(start, cursor));
    }

    private MathMLNode command() throws ParseException {
        require("\\");
        if (cursor >= source.length()) {
            throw new ParseException();
        }
        if (!Character.isLetter(source.charAt(cursor))) {
            char escaped = source.charAt(cursor++);
            if (escaped == '!') {
                return MathMLNode.row(Collections.<MathMLNode>emptyList());
            }
            if ("{}()[]|%".indexOf(escaped) < 0) {
                throw new ParseException();
            }
            return MathMLNode.operator(String.valueOf(escaped));
        }

        String name = commandName();
        if ("frac".equals(name) || "tfrac".equals(name)) {
            return MathMLNode.fraction(argument(), argument());
        }
        if ("sqrt".equals(name)) {
            return squareRoot();
        }
        if ("text".equals(name)) {
            return MathMLNode.spacedText(textArgument());
        }
        if ("mathrm".equals(name)) {
            return MathMLNode.style(argument(), "normal");
        }
        if ("mathbf".equals(name)) {
            return MathMLNode.style(argument(), "bold");
        }
        if ("mathcal".equals(name)) {
            return MathMLNode.style(argument(), "script");
        }
        if ("operatorname".equals(name)) {
            return MathMLNode.operator(textArgument());
        }
        if ("hat".equals(name) || "bar".equals(name) || "vec".equals(name)
                || "overline".equals(name)) {
            return MathMLNode.accent(argument(), accentMark(name));
        }
        if ("left".equals(name)) {
            String open = delimiter();
            MathMLNode content = sequence(Terminator.RIGHT);
            require("\\right");
            return MathMLNode.fenced(open, delimiter(), content);
        }
        if ("begin".equals(name)) {
            return environment(nameArgument());
        }
        if (LIMIT_OPERATORS.contains(name)) {
            return MathMLNode.limitOperator(limitSymbol(name));
        }
        if (NAMED_OPERATORS.contains(name)) {
            return MathMLNode.operator(name);
        }
        String symbol = SYMBOLS.get(name);
        if (symbol == null) {
            throw new ParseException();
        }
        return IDENTIFIERS.contains(name)
                ? MathMLNode.identifier(symbol)
                : MathMLNode.operator(symbol);
    }

    private MathMLNode squareRoot() throws ParseException {
        skipSpaces();
        if (!take("[")) {
            return MathMLNode.squareRoot(argument());
        }
        MathMLNode index = sequence(Terminator.INDEX);
        require("]");
        return MathMLNode.indexedRoot(argument(), index);
    }

    private MathMLNode argument() throws ParseException {
        skipSpaces();
        if (take("{")) {
            MathMLNode content = sequence(Terminator.GROUP);
            require("}");
            return content;
        }
        return atom();
    }

    private String textArgument() throws ParseException {
        skipSpaces();
        require("{");
        int start = cursor;
        int depth = 1;
        while (cursor < source.length() && depth > 0) {
            char current = source.charAt(cursor++);
            if (current == '{') {
                depth++;
            } else if (current == '}') {
                depth--;
            }
        }
        if (depth != 0) {
            throw new ParseException();
        }
        return source.substring(start, cursor - 1);
    }

    private String nameArgument() throws ParseException {
        String value = textArgument().trim();
        if (value.isEmpty()) {
            throw new ParseException();
        }
        return value;
    }

    private MathMLNode environment(String name) throws ParseException {
        if (!"matrix".equals(name) && !"pmatrix".equals(name)
                && !"cases".equals(name) && !"aligned".equals(name)) {
            throw new ParseException();
        }
        List<List<MathMLNode>> rows = new ArrayList<List<MathMLNode>>();
        List<MathMLNode> cells = new ArrayList<MathMLNode>();
        while (cursor < source.length()) {
            skipSpaces();
            if (startsWith("\\end{" + name + "}")) {
                cursor += ("\\end{" + name + "}").length();
                if (!cells.isEmpty()) {
                    rows.add(cells);
                }
                MathMLNode table = MathMLNode.table(rows);
                if ("pmatrix".equals(name)) {
                    return MathMLNode.environmentFenced("(", ")", table, rows.size());
                }
                if ("cases".equals(name)) {
                    return MathMLNode.environmentFenced("{", "", table, rows.size());
                }
                return table;
            }
            cells.add(sequence(Terminator.ENVIRONMENT_CELL));
            if (take("&")) {
                continue;
            }
            if (take("\\\\")) {
                rows.add(cells);
                cells = new ArrayList<MathMLNode>();
                continue;
            }
            if (!startsWith("\\end{" + name + "}")) {
                throw new ParseException();
            }
        }
        throw new ParseException();
    }

    private String delimiter() throws ParseException {
        skipSpaces();
        if (cursor >= source.length()) {
            throw new ParseException();
        }
        char current = source.charAt(cursor);
        if (current == '.') {
            cursor++;
            return "";
        }
        if (current != '\\') {
            cursor++;
            return String.valueOf(current);
        }
        cursor++;
        if (cursor >= source.length()) {
            throw new ParseException();
        }
        if (!Character.isLetter(source.charAt(cursor))) {
            return String.valueOf(source.charAt(cursor++));
        }
        String name = commandName();
        if ("lbrace".equals(name)) {
            return "{";
        }
        if ("rbrace".equals(name)) {
            return "}";
        }
        if ("langle".equals(name)) {
            return "⟨";
        }
        if ("rangle".equals(name)) {
            return "⟩";
        }
        String value = SYMBOLS.get(name);
        if (value == null || (!name.contains("vert") && !name.contains("Vert"))) {
            throw new ParseException();
        }
        return value;
    }

    private String commandName() {
        int start = cursor;
        while (cursor < source.length() && Character.isLetter(source.charAt(cursor))) {
            cursor++;
        }
        return source.substring(start, cursor);
    }

    private boolean isAt(Terminator terminator) {
        switch (terminator) {
        case END:
            return cursor >= source.length();
        case GROUP:
            return startsWith("}");
        case INDEX:
            return startsWith("]");
        case RIGHT:
            return startsWithCommand("\\right");
        case ENVIRONMENT_CELL:
            return startsWith("&") || startsWith("\\\\") || startsWith("\\end{");
        default:
            return false;
        }
    }

    private void skipSpaces() {
        while (cursor < source.length() && Character.isWhitespace(source.charAt(cursor))) {
            cursor++;
        }
    }

    private boolean take(String value) {
        if (!startsWith(value)) {
            return false;
        }
        cursor += value.length();
        return true;
    }

    private void require(String value) throws ParseException {
        if (!take(value)) {
            throw new ParseException();
        }
    }

    private boolean startsWith(String value) {
        return source.startsWith(value, cursor);
    }

    private boolean startsWithCommand(String value) {
        if (!startsWith(value)) {
            return false;
        }
        int end = cursor + value.length();
        return end >= source.length() || !Character.isLetter(source.charAt(end));
    }

    private static String accentMark(String name) {
        if ("hat".equals(name)) {
            return "^";
        }
        if ("vec".equals(name)) {
            return "→";
        }
        return "¯";
    }

    private static String limitSymbol(String name) {
        if ("sum".equals(name)) {
            return "∑";
        }
        if ("prod".equals(name)) {
            return "∏";
        }
        return "∫";
    }

    private static final class ParseException extends Exception {
        private static final long serialVersionUID = 1L;
    }
}

package com.smartwallet.smart_wallet;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * A tiny JSON parser/writer in pure Java — no Android imports, no
 * libraries — so the backup/CSV codecs built on it can run in the JVM
 * tests (org.json only exists inside Android). Values map to
 * LinkedHashMap (insertion order preserved, like Dart maps), List,
 * String, Long (integer literals), Double (decimal literals), Boolean
 * and null.
 *
 * The writer formats doubles the way Dart's jsonEncode does for the
 * values this app writes: integral doubles print as "54200.0", other
 * doubles in plain (non-exponent) decimal form.
 */
public final class MiniJson {

    private MiniJson() {}

    public static class JsonException extends Exception {
        public JsonException(String msg) { super(msg); }
    }

    // ---------------------------------------------------------------- write

    public static String write(Object value) {
        StringBuilder sb = new StringBuilder();
        writeValue(sb, value);
        return sb.toString();
    }

    private static void writeValue(StringBuilder sb, Object v) {
        if (v == null) {
            sb.append("null");
        } else if (v instanceof String) {
            writeString(sb, (String) v);
        } else if (v instanceof Boolean) {
            sb.append(((Boolean) v).booleanValue() ? "true" : "false");
        } else if (v instanceof Double || v instanceof Float) {
            sb.append(dartDouble(((Number) v).doubleValue()));
        } else if (v instanceof Number) {
            sb.append(v.toString());
        } else if (v instanceof Map) {
            sb.append('{');
            boolean first = true;
            for (Map.Entry<?, ?> e : ((Map<?, ?>) v).entrySet()) {
                if (!first) sb.append(',');
                first = false;
                writeString(sb, String.valueOf(e.getKey()));
                sb.append(':');
                writeValue(sb, e.getValue());
            }
            sb.append('}');
        } else if (v instanceof List) {
            sb.append('[');
            boolean first = true;
            for (Object item : (List<?>) v) {
                if (!first) sb.append(',');
                first = false;
                writeValue(sb, item);
            }
            sb.append(']');
        } else {
            writeString(sb, String.valueOf(v));
        }
    }

    private static void writeString(StringBuilder sb, String s) {
        sb.append('"');
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '"': sb.append("\\\""); break;
                case '\\': sb.append("\\\\"); break;
                case '\n': sb.append("\\n"); break;
                case '\r': sb.append("\\r"); break;
                case '\t': sb.append("\\t"); break;
                case '\b': sb.append("\\b"); break;
                case '\f': sb.append("\\f"); break;
                default:
                    if (c < 0x20) {
                        sb.append(String.format("\\u%04x", (int) c));
                    } else {
                        sb.append(c);
                    }
            }
        }
        sb.append('"');
    }

    /**
     * Dart-style double formatting: 54200.0 -> "54200.0",
     * 1850.5 -> "1850.5", 0.0001 -> "0.0001" (never exponent form).
     * NaN/Infinity are not valid JSON; Dart's jsonEncode throws on
     * them, this writer emits null instead (money values are finite).
     */
    public static String dartDouble(double d) {
        if (Double.isNaN(d) || Double.isInfinite(d)) return "null";
        if (d == 0.0) return "0.0";
        return BigDecimal.valueOf(d).toPlainString();
    }

    // ---------------------------------------------------------------- parse

    public static Object parse(String text) throws JsonException {
        if (text == null) throw new JsonException("null JSON text");
        Parser p = new Parser(text);
        p.skipWs();
        Object v = p.readValue();
        p.skipWs();
        if (!p.atEnd()) throw new JsonException("Trailing characters after JSON value");
        return v;
    }

    /** Parse and require a top-level object. */
    @SuppressWarnings("unchecked")
    public static Map<String, Object> parseObject(String text) throws JsonException {
        Object v = parse(text);
        if (!(v instanceof Map)) throw new JsonException("Top-level JSON value is not an object");
        return (Map<String, Object>) v;
    }

    private static final class Parser {
        private final String s;
        private int pos;

        Parser(String s) { this.s = s; }

        boolean atEnd() { return pos >= s.length(); }

        void skipWs() {
            while (pos < s.length()) {
                char c = s.charAt(pos);
                if (c == ' ' || c == '\t' || c == '\n' || c == '\r') pos++;
                else break;
            }
        }

        private char peek() throws JsonException {
            if (pos >= s.length()) throw new JsonException("Unexpected end of JSON");
            return s.charAt(pos);
        }

        Object readValue() throws JsonException {
            char c = peek();
            switch (c) {
                case '{': return readObject();
                case '[': return readArray();
                case '"': return readString();
                case 't': expect("true"); return Boolean.TRUE;
                case 'f': expect("false"); return Boolean.FALSE;
                case 'n': expect("null"); return null;
                default:
                    if (c == '-' || (c >= '0' && c <= '9')) return readNumber();
                    throw new JsonException("Unexpected character '" + c + "' at " + pos);
            }
        }

        private void expect(String literal) throws JsonException {
            if (!s.startsWith(literal, pos)) {
                throw new JsonException("Invalid literal at " + pos);
            }
            pos += literal.length();
        }

        private Map<String, Object> readObject() throws JsonException {
            Map<String, Object> map = new LinkedHashMap<>();
            pos++; // {
            skipWs();
            if (peek() == '}') { pos++; return map; }
            while (true) {
                skipWs();
                if (peek() != '"') throw new JsonException("Expected object key at " + pos);
                String key = readString();
                skipWs();
                if (peek() != ':') throw new JsonException("Expected ':' at " + pos);
                pos++;
                skipWs();
                map.put(key, readValue());
                skipWs();
                char c = peek();
                if (c == ',') { pos++; continue; }
                if (c == '}') { pos++; return map; }
                throw new JsonException("Expected ',' or '}' at " + pos);
            }
        }

        private List<Object> readArray() throws JsonException {
            List<Object> list = new ArrayList<>();
            pos++; // [
            skipWs();
            if (peek() == ']') { pos++; return list; }
            while (true) {
                skipWs();
                list.add(readValue());
                skipWs();
                char c = peek();
                if (c == ',') { pos++; continue; }
                if (c == ']') { pos++; return list; }
                throw new JsonException("Expected ',' or ']' at " + pos);
            }
        }

        private String readString() throws JsonException {
            StringBuilder sb = new StringBuilder();
            pos++; // opening quote
            while (true) {
                if (pos >= s.length()) throw new JsonException("Unterminated string");
                char c = s.charAt(pos++);
                if (c == '"') return sb.toString();
                if (c == '\\') {
                    if (pos >= s.length()) throw new JsonException("Unterminated escape");
                    char e = s.charAt(pos++);
                    switch (e) {
                        case '"': sb.append('"'); break;
                        case '\\': sb.append('\\'); break;
                        case '/': sb.append('/'); break;
                        case 'b': sb.append('\b'); break;
                        case 'f': sb.append('\f'); break;
                        case 'n': sb.append('\n'); break;
                        case 'r': sb.append('\r'); break;
                        case 't': sb.append('\t'); break;
                        case 'u':
                            if (pos + 4 > s.length()) {
                                throw new JsonException("Bad \\u escape");
                            }
                            try {
                                sb.append((char) Integer.parseInt(
                                        s.substring(pos, pos + 4), 16));
                            } catch (NumberFormatException nfe) {
                                throw new JsonException("Bad \\u escape");
                            }
                            pos += 4;
                            break;
                        default:
                            throw new JsonException("Bad escape '\\" + e + "'");
                    }
                } else {
                    sb.append(c);
                }
            }
        }

        private Number readNumber() throws JsonException {
            int start = pos;
            boolean isDouble = false;
            if (pos < s.length() && s.charAt(pos) == '-') pos++;
            while (pos < s.length()) {
                char c = s.charAt(pos);
                if (c >= '0' && c <= '9') {
                    pos++;
                } else if (c == '.' || c == 'e' || c == 'E' || c == '+' || c == '-') {
                    if (c == '.' || c == 'e' || c == 'E') isDouble = true;
                    pos++;
                } else {
                    break;
                }
            }
            String num = s.substring(start, pos);
            try {
                if (isDouble) return Double.valueOf(num);
                try {
                    return Long.valueOf(num);
                } catch (NumberFormatException overflow) {
                    return Double.valueOf(num);
                }
            } catch (NumberFormatException e) {
                throw new JsonException("Invalid number '" + num + "'");
            }
        }
    }
}

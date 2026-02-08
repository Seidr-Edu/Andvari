package org.java_websocket.util;

import java.nio.ByteBuffer;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;

public final class Charsetfunctions {

    public static final Charset UTF8 = StandardCharsets.UTF_8;

    private Charsetfunctions() {
    }

    public static ByteBuffer utf8Bytes(final String value) {
        return ByteBuffer.wrap(value.getBytes(UTF8));
    }

    public static String stringUtf8(final ByteBuffer value) {
        final ByteBuffer copy = value.asReadOnlyBuffer();
        final byte[] bytes = new byte[copy.remaining()];
        copy.get(bytes);
        return new String(bytes, UTF8);
    }
}

package org.java_websocket.util;

import java.nio.ByteBuffer;

public final class ByteBufferUtils {

    private ByteBufferUtils() {
    }

    public static ByteBuffer getEmptyByteBuffer() {
        return ByteBuffer.allocate(0);
    }

    public static ByteBuffer copyOf(final ByteBuffer source) {
        final ByteBuffer readOnly = source.asReadOnlyBuffer();
        final byte[] data = new byte[readOnly.remaining()];
        readOnly.get(data);
        return ByteBuffer.wrap(data);
    }
}

package org.java_websocket.framing;

import java.nio.ByteBuffer;
import org.java_websocket.enums.Opcode;

public class TextFrame extends DataFrame {

    public TextFrame() {
        super(Opcode.TEXT);
    }

    public TextFrame(final ByteBuffer payload) {
        super(Opcode.TEXT, payload);
    }
}

package org.java_websocket.framing;

import java.nio.ByteBuffer;
import org.java_websocket.enums.Opcode;

public class DataFrame extends FramedataImpl1 {

    protected DataFrame(final Opcode opcode) {
        super(opcode);
    }

    protected DataFrame(final Opcode opcode, final ByteBuffer payload) {
        super(true, opcode, payload);
    }
}

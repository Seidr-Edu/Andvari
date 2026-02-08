package org.java_websocket.framing;

import org.java_websocket.enums.Opcode;

public class ControlFrame extends FramedataImpl1 {

    protected ControlFrame(final Opcode opcode) {
        super(opcode);
    }
}

package org.java_websocket.framing;

import java.nio.ByteBuffer;
import org.java_websocket.enums.Opcode;

public interface Framedata {

    boolean isFin();

    Opcode getOpcode();

    ByteBuffer getPayloadData();
}

package org.java_websocket.framing;

import java.nio.ByteBuffer;
import org.java_websocket.enums.Opcode;
import org.java_websocket.exceptions.InvalidDataException;
import org.java_websocket.util.Charsetfunctions;

public class CloseFrame extends ControlFrame {

    public static final int NORMAL = 1000;

    private int code = NORMAL;
    private String reason = "";

    public CloseFrame() {
        super(Opcode.CLOSING);
    }

    public int getCloseCode() {
        return code;
    }

    public String getMessage() {
        return reason;
    }

    public void setCode(final int value) throws InvalidDataException {
        if (value < 1000) {
            throw new InvalidDataException("close code must be >= 1000");
        }
        code = value;
    }

    public void setReason(final String value) {
        reason = value == null ? "" : value;
    }

    public void updatePayload() {
        final byte[] text = reason.getBytes(Charsetfunctions.UTF8);
        final ByteBuffer payload = ByteBuffer.allocate(2 + text.length);
        payload.putShort((short) code);
        payload.put(text);
        payload.flip();
        setPayload(payload);
    }
}

package org.java_websocket.framing;

import java.nio.ByteBuffer;
import java.util.Objects;
import org.java_websocket.enums.Opcode;

public class FramedataImpl1 implements Framedata {

    private boolean fin;
    private Opcode opcode;
    private ByteBuffer payload;

    protected FramedataImpl1(final boolean fin, final Opcode opcode, final ByteBuffer payload) {
        this.fin = fin;
        this.opcode = Objects.requireNonNull(opcode, "opcode");
        this.payload = payload == null ? ByteBuffer.allocate(0) : payload.slice();
    }

    protected FramedataImpl1(final Opcode opcode) {
        this(true, opcode, ByteBuffer.allocate(0));
    }

    public void setPayload(final ByteBuffer value) {
        payload = value == null ? ByteBuffer.allocate(0) : value.slice();
    }

    public void setFin(final boolean value) {
        fin = value;
    }

    @Override
    public boolean isFin() {
        return fin;
    }

    @Override
    public Opcode getOpcode() {
        return opcode;
    }

    @Override
    public ByteBuffer getPayloadData() {
        return payload.asReadOnlyBuffer();
    }

    protected void setOpcode(final Opcode value) {
        opcode = Objects.requireNonNull(value, "opcode");
    }
}

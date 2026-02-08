package org.java_websocket.handshake;

public class HandshakeImpl1Server extends HandshakedataImpl1 implements ServerHandshakeBuilder {

    private short status = 101;
    private String statusMessage = "Switching Protocols";

    @Override
    public short getHttpStatus() {
        return status;
    }

    @Override
    public String getHttpStatusMessage() {
        return statusMessage;
    }

    @Override
    public void setHttpStatus(final short value) {
        status = value;
    }

    @Override
    public void setHttpStatusMessage(final String value) {
        statusMessage = value == null ? "" : value;
    }
}

package org.java_websocket.handshake;

public class HandshakeImpl1Client extends HandshakedataImpl1 implements ClientHandshakeBuilder {

    private String resourceDescriptor = "/";

    @Override
    public String getResourceDescriptor() {
        return resourceDescriptor;
    }

    @Override
    public void setResourceDescriptor(final String value) {
        resourceDescriptor = (value == null || value.isBlank()) ? "/" : value;
    }
}

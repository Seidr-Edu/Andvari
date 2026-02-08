package org.java_websocket.handshake;

import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;

public class HandshakedataImpl1 implements HandshakeBuilder {

    private final Map<String, String> fields = new LinkedHashMap<>();
    private byte[] content = new byte[0];

    @Override
    public String getFieldValue(final String name) {
        return fields.getOrDefault(name, "");
    }

    @Override
    public boolean hasFieldValue(final String name) {
        return fields.containsKey(name);
    }

    @Override
    public Map<String, String> getHttpFields() {
        return Collections.unmodifiableMap(fields);
    }

    @Override
    public byte[] getContent() {
        return content.clone();
    }

    @Override
    public void put(final String name, final String value) {
        fields.put(name, value);
    }

    @Override
    public void setContent(final byte[] body) {
        content = body == null ? new byte[0] : body.clone();
    }
}

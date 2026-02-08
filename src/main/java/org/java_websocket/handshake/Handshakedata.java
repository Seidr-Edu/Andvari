package org.java_websocket.handshake;

import java.util.Map;

public interface Handshakedata {

    String getFieldValue(String name);

    boolean hasFieldValue(String name);

    Map<String, String> getHttpFields();

    byte[] getContent();
}

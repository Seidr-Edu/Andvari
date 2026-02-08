package org.java_websocket.protocols;

public interface IProtocol {

    boolean acceptProvidedProtocol(String inputProtocolHeader);

    String getProvidedProtocol();

    IProtocol copyInstance();
}

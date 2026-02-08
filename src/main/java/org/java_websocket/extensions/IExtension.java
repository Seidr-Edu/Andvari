package org.java_websocket.extensions;

import org.java_websocket.framing.Framedata;

public interface IExtension {

    String getProvidedExtensionAsServer();

    boolean acceptProvidedExtensionAsServer(String extensionHeader);

    void encodeFrame(Framedata frame);

    void decodeFrame(Framedata frame);

    IExtension copyInstance();
}

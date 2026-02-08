package org.java_websocket.extensions;

import org.java_websocket.framing.Framedata;

public class DefaultExtension implements IExtension {

    @Override
    public String getProvidedExtensionAsServer() {
        return "";
    }

    @Override
    public boolean acceptProvidedExtensionAsServer(final String extensionHeader) {
        return extensionHeader == null || extensionHeader.isBlank();
    }

    @Override
    public void encodeFrame(final Framedata frame) {
        // no-op
    }

    @Override
    public void decodeFrame(final Framedata frame) {
        // no-op
    }

    @Override
    public IExtension copyInstance() {
        return new DefaultExtension();
    }
}

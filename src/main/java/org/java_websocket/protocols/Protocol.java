package org.java_websocket.protocols;

import java.util.Arrays;
import java.util.Objects;

public class Protocol implements IProtocol {

    private final String providedProtocol;

    public Protocol(final String providedProtocol) {
        this.providedProtocol = providedProtocol == null ? "" : providedProtocol.trim();
    }

    @Override
    public boolean acceptProvidedProtocol(final String inputProtocolHeader) {
        if (providedProtocol.isEmpty()) {
            return inputProtocolHeader == null || inputProtocolHeader.isBlank();
        }
        if (inputProtocolHeader == null) {
            return false;
        }
        return Arrays.stream(inputProtocolHeader.split(","))
                .map(String::trim)
                .anyMatch(token -> token.equals(providedProtocol));
    }

    @Override
    public String getProvidedProtocol() {
        return providedProtocol;
    }

    @Override
    public IProtocol copyInstance() {
        return new Protocol(providedProtocol);
    }

    @Override
    public int hashCode() {
        return Objects.hash(providedProtocol);
    }

    @Override
    public boolean equals(final Object obj) {
        if (this == obj) {
            return true;
        }
        if (!(obj instanceof Protocol other)) {
            return false;
        }
        return Objects.equals(providedProtocol, other.providedProtocol);
    }

    @Override
    public String toString() {
        return providedProtocol;
    }
}

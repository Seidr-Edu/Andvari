package org.java_websocket.exceptions;

public class InvalidHandshakeException extends Exception {

    private static final long serialVersionUID = 1L;

    public InvalidHandshakeException(final String message) {
        super(message);
    }
}

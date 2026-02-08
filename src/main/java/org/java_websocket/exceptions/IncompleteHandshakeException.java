package org.java_websocket.exceptions;

public class IncompleteHandshakeException extends Exception {

    private static final long serialVersionUID = 1L;

    public IncompleteHandshakeException(final String message) {
        super(message);
    }
}

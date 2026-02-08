package org.java_websocket.exceptions;

public class InvalidDataException extends Exception {
    private static final long serialVersionUID = 1L;

    public InvalidDataException(final String message) {
        super(message);
    }
}

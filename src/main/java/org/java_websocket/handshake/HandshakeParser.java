package org.java_websocket.handshake;

import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import org.java_websocket.exceptions.IncompleteHandshakeException;
import org.java_websocket.exceptions.InvalidHandshakeException;

public final class HandshakeParser {

    private HandshakeParser() {
    }

    public static HandshakeImpl1Client parseClientHandshake(final byte[] raw)
            throws InvalidHandshakeException, IncompleteHandshakeException {
        final String content = new String(raw, StandardCharsets.US_ASCII);
        if (!content.contains("\r\n\r\n")) {
            throw new IncompleteHandshakeException("Handshake terminator not found");
        }

        final String[] lines = content.split("\\r\\n");
        if (lines.length < 1) {
            throw new InvalidHandshakeException("No request line found");
        }

        final String[] requestLine = lines[0].split(" ");
        if (requestLine.length < 3 || !"GET".equals(requestLine[0])) {
            throw new InvalidHandshakeException("Invalid request line");
        }

        final HandshakeImpl1Client handshake = new HandshakeImpl1Client();
        handshake.setResourceDescriptor(requestLine[1]);

        for (final String line : copyHeaders(lines)) {
            final int splitIndex = line.indexOf(':');
            if (splitIndex <= 0) {
                continue;
            }
            final String key = line.substring(0, splitIndex).trim();
            final String value = line.substring(splitIndex + 1).trim();
            handshake.put(key, value);
        }
        return handshake;
    }

    public static byte[] buildClientHandshake(final ClientHandshake handshake) {
        final StringBuilder builder = new StringBuilder();
        builder.append("GET ")
                .append(handshake.getResourceDescriptor())
                .append(" HTTP/1.1\r\n");
        handshake.getHttpFields().forEach((key, value) -> builder.append(key)
                .append(": ")
                .append(value)
                .append("\r\n"));
        builder.append("\r\n");
        return builder.toString().getBytes(StandardCharsets.US_ASCII);
    }

    private static List<String> copyHeaders(final String[] lines) {
        final List<String> headers = new ArrayList<>();
        for (int index = 1; index < lines.length; index++) {
            final String line = lines[index];
            if (line.isEmpty()) {
                break;
            }
            headers.add(line);
        }
        return headers;
    }
}

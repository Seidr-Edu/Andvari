package org.java_websocket.drafts;

import java.nio.ByteBuffer;
import java.security.MessageDigest;
import java.util.List;
import org.java_websocket.enums.CloseHandshakeType;
import org.java_websocket.enums.HandshakeState;
import org.java_websocket.enums.Opcode;
import org.java_websocket.exceptions.IncompleteHandshakeException;
import org.java_websocket.exceptions.InvalidDataException;
import org.java_websocket.exceptions.InvalidHandshakeException;
import org.java_websocket.framing.Framedata;
import org.java_websocket.framing.TextFrame;
import org.java_websocket.handshake.ClientHandshake;
import org.java_websocket.handshake.ClientHandshakeBuilder;
import org.java_websocket.handshake.HandshakeImpl1Client;
import org.java_websocket.handshake.HandshakeParser;
import org.java_websocket.handshake.ServerHandshakeBuilder;
import org.java_websocket.util.Base64;

public class Draft_6455 extends Draft {

    public static final String SEC_WEB_SOCKET_KEY = "Sec-WebSocket-Key";
    public static final String SEC_WEB_SOCKET_ACCEPT = "Sec-WebSocket-Accept";
    public static final String SEC_WEB_SOCKET_VERSION = "Sec-WebSocket-Version";
    private static final String WEB_SOCKET_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";

    @Override
    public ByteBuffer createBinaryFrame(final Framedata frame) {
        if (frame.getOpcode() != Opcode.TEXT) {
            throw new IllegalArgumentException("Only text frames are supported in this iteration");
        }
        final ByteBuffer payload = frame.getPayloadData();
        final int size = payload.remaining();
        if (size > 125) {
            throw new IllegalArgumentException("Payload too large for a single basic frame");
        }

        final ByteBuffer result = ByteBuffer.allocate(size + 2);
        result.put((byte) 0x81);
        result.put((byte) size);
        result.put(payload);
        result.flip();
        return result;
    }

    @Override
    public List<Framedata> translateFrame(final ByteBuffer input) throws InvalidDataException {
        if (input.remaining() < 2) {
            throw new InvalidDataException("Incomplete frame header");
        }

        final byte b0 = input.get();
        final byte b1 = input.get();

        final int opcode = b0 & 0x0F;
        if (opcode != 0x1) {
            throw new InvalidDataException("Only opcode 0x1 (text) is supported");
        }

        final boolean masked = (b1 & 0x80) != 0;
        if (masked) {
            throw new InvalidDataException("Masked frames are not supported in this iteration");
        }

        final int payloadLength = b1 & 0x7F;
        if (input.remaining() != payloadLength) {
            throw new InvalidDataException("Payload length mismatch");
        }

        final byte[] payload = new byte[payloadLength];
        input.get(payload);
        return List.of(new TextFrame(ByteBuffer.wrap(payload)));
    }

    @Override
    public HandshakeState acceptHandshakeAsServer(final ClientHandshake request)
            throws InvalidHandshakeException {
        if (!request.hasFieldValue(SEC_WEB_SOCKET_VERSION)
                || !"13".equals(request.getFieldValue(SEC_WEB_SOCKET_VERSION))) {
            throw new InvalidHandshakeException("Unsupported WebSocket version");
        }
        if (!request.hasFieldValue(SEC_WEB_SOCKET_KEY)
                || request.getFieldValue(SEC_WEB_SOCKET_KEY).isBlank()) {
            return HandshakeState.NOT_MATCHED;
        }
        return HandshakeState.MATCHED;
    }

    @Override
    public ClientHandshakeBuilder postProcessHandshakeRequestAsClient(
            final ClientHandshakeBuilder request) {
        request.put("Upgrade", "websocket");
        request.put("Connection", "Upgrade");
        request.put(SEC_WEB_SOCKET_VERSION, "13");
        if (!request.hasFieldValue(SEC_WEB_SOCKET_KEY)) {
            request.put(SEC_WEB_SOCKET_KEY, "dGhlIHNhbXBsZSBub25jZQ==");
        }
        return request;
    }

    @Override
    public ServerHandshakeBuilder postProcessHandshakeResponseAsServer(
            final ClientHandshake request,
            final ServerHandshakeBuilder response) throws InvalidHandshakeException {
        final HandshakeState state = acceptHandshakeAsServer(request);
        if (state != HandshakeState.MATCHED) {
            throw new InvalidHandshakeException("Handshake request not matched");
        }
        response.put("Upgrade", "websocket");
        response.put("Connection", "Upgrade");
        response.put(SEC_WEB_SOCKET_ACCEPT, generateFinalKey(request.getFieldValue(SEC_WEB_SOCKET_KEY)));
        return response;
    }

    @Override
    public CloseHandshakeType getCloseHandshakeType() {
        return CloseHandshakeType.TWOWAY;
    }

    @Override
    public HandshakeImpl1Client translateHandshake(final byte[] raw)
            throws InvalidHandshakeException, IncompleteHandshakeException {
        return HandshakeParser.parseClientHandshake(raw);
    }

    @Override
    public byte[] createHandshake(final ClientHandshake request) {
        return HandshakeParser.buildClientHandshake(request);
    }

    String generateFinalKey(final String key) throws InvalidHandshakeException {
        try {
            final MessageDigest digest = MessageDigest.getInstance("SHA-1");
            final byte[] encoded = digest.digest((key + WEB_SOCKET_GUID).getBytes());
            return Base64.encodeBytes(encoded);
        } catch (final Exception exception) {
            throw new InvalidHandshakeException("Unable to generate websocket accept key");
        }
    }
}

package org.java_websocket.drafts;

import java.nio.ByteBuffer;
import java.util.List;
import org.java_websocket.enums.CloseHandshakeType;
import org.java_websocket.enums.HandshakeState;
import org.java_websocket.exceptions.IncompleteHandshakeException;
import org.java_websocket.exceptions.InvalidDataException;
import org.java_websocket.exceptions.InvalidHandshakeException;
import org.java_websocket.framing.Framedata;
import org.java_websocket.handshake.ClientHandshake;
import org.java_websocket.handshake.ClientHandshakeBuilder;
import org.java_websocket.handshake.HandshakeImpl1Client;
import org.java_websocket.handshake.ServerHandshakeBuilder;

public abstract class Draft {

    public abstract ByteBuffer createBinaryFrame(Framedata frame);

    public abstract List<Framedata> translateFrame(ByteBuffer input) throws InvalidDataException;

    public abstract HandshakeState acceptHandshakeAsServer(ClientHandshake request)
            throws InvalidHandshakeException;

    public abstract ClientHandshakeBuilder postProcessHandshakeRequestAsClient(
            ClientHandshakeBuilder request);

    public abstract ServerHandshakeBuilder postProcessHandshakeResponseAsServer(
            ClientHandshake request, ServerHandshakeBuilder response) throws InvalidHandshakeException;

    public abstract CloseHandshakeType getCloseHandshakeType();

    public abstract HandshakeImpl1Client translateHandshake(byte[] raw)
            throws InvalidHandshakeException, IncompleteHandshakeException;

    public abstract byte[] createHandshake(ClientHandshake request);
}

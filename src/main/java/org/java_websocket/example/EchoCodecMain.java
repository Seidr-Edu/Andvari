package org.java_websocket.example;

import java.nio.ByteBuffer;
import org.java_websocket.drafts.Draft_6455;
import org.java_websocket.framing.TextFrame;
import org.java_websocket.handshake.HandshakeImpl1Client;
import org.java_websocket.handshake.HandshakeImpl1Server;
import org.java_websocket.util.Charsetfunctions;

public final class EchoCodecMain {

    private EchoCodecMain() {
    }

    public static void main(final String[] args) throws Exception {
        final Draft_6455 draft = new Draft_6455();

        final HandshakeImpl1Client client = new HandshakeImpl1Client();
        client.setResourceDescriptor("/echo");
        draft.postProcessHandshakeRequestAsClient(client);

        final byte[] serialized = draft.createHandshake(client);
        final HandshakeImpl1Client parsed = draft.translateHandshake(serialized);

        final HandshakeImpl1Server server = new HandshakeImpl1Server();
        draft.postProcessHandshakeResponseAsServer(parsed, server);

        final ByteBuffer raw = draft.createBinaryFrame(new TextFrame(Charsetfunctions.utf8Bytes("hello")));
        final String decoded = Charsetfunctions.stringUtf8(draft.translateFrame(raw).get(0).getPayloadData());
        System.out.println(server.getHttpStatus() + " " + parsed.getResourceDescriptor() + " " + decoded);
    }
}

package org.java_websocket.tests;

import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import org.java_websocket.drafts.Draft_6455;
import org.java_websocket.enums.CloseHandshakeType;
import org.java_websocket.enums.HandshakeState;
import org.java_websocket.exceptions.InvalidDataException;
import org.java_websocket.extensions.ExtensionRequestData;
import org.java_websocket.framing.CloseFrame;
import org.java_websocket.framing.TextFrame;
import org.java_websocket.handshake.HandshakeImpl1Client;
import org.java_websocket.handshake.HandshakeImpl1Server;
import org.java_websocket.protocols.Protocol;
import org.java_websocket.util.Base64;
import org.java_websocket.util.ByteBufferUtils;
import org.java_websocket.util.Charsetfunctions;

public final class TestMain {

    private TestMain() {
    }

    public static void main(final String[] args) throws Exception {
        shouldEncodeAndDecodeTextFrame();
        shouldRejectUnsupportedOpcode();
        shouldRoundTripUtf8String();
        shouldBuildClientAndServerHandshake();
        shouldTranslateRawHandshake();
        shouldParseExtensionRequest();
        shouldMatchProtocolHeader();
        shouldBuildCloseFramePayload();
        shouldEncodeAndDecodeBase64();
        shouldCopyByteBuffer();
        System.out.println("All tests passed.");
    }

    private static void shouldEncodeAndDecodeTextFrame() throws Exception {
        final Draft_6455 draft = new Draft_6455();

        final ByteBuffer encoded = draft.createBinaryFrame(new TextFrame(Charsetfunctions.utf8Bytes("hello")));
        final String decoded = Charsetfunctions.stringUtf8(draft.translateFrame(encoded).getFirst().getPayloadData());

        assertEquals("hello", decoded, "Text frame decode");
    }

    private static void shouldRejectUnsupportedOpcode() {
        final Draft_6455 draft = new Draft_6455();
        final ByteBuffer invalidFrame = ByteBuffer.wrap(new byte[] {(byte) 0x82, 0x00});

        try {
            draft.translateFrame(invalidFrame);
            throw new AssertionError("Expected InvalidDataException for binary opcode");
        } catch (final InvalidDataException expected) {
            // expected path
        }
    }

    private static void shouldRoundTripUtf8String() {
        final ByteBuffer bytes = Charsetfunctions.utf8Bytes("hëllö");
        assertEquals("hëllö", Charsetfunctions.stringUtf8(bytes), "UTF-8 roundtrip");
    }

    private static void shouldBuildClientAndServerHandshake() throws Exception {
        final Draft_6455 draft = new Draft_6455();
        final HandshakeImpl1Client request = new HandshakeImpl1Client();
        request.setResourceDescriptor("/chat");

        draft.postProcessHandshakeRequestAsClient(request);
        assertEquals("13", request.getFieldValue(Draft_6455.SEC_WEB_SOCKET_VERSION), "Handshake version");
        assertEquals(HandshakeState.MATCHED.name(), draft.acceptHandshakeAsServer(request).name(), "Handshake match");

        final HandshakeImpl1Server response = new HandshakeImpl1Server();
        draft.postProcessHandshakeResponseAsServer(request, response);
        assertTrue(response.hasFieldValue(Draft_6455.SEC_WEB_SOCKET_ACCEPT), "Accept header exists");
        assertEquals(CloseHandshakeType.TWOWAY.name(), draft.getCloseHandshakeType().name(), "Close handshake type");
    }

    private static void shouldTranslateRawHandshake() throws Exception {
        final Draft_6455 draft = new Draft_6455();
        final HandshakeImpl1Client request = new HandshakeImpl1Client();
        request.setResourceDescriptor("/ws");
        request.put("Host", "localhost");
        request.put(Draft_6455.SEC_WEB_SOCKET_KEY, "dGhlIHNhbXBsZSBub25jZQ==");
        request.put(Draft_6455.SEC_WEB_SOCKET_VERSION, "13");

        final byte[] serialized = draft.createHandshake(request);
        final HandshakeImpl1Client parsed = draft.translateHandshake(serialized);
        assertEquals("/ws", parsed.getResourceDescriptor(), "Parsed resource");
        assertEquals("localhost", parsed.getFieldValue("Host"), "Parsed host");
    }

    private static void shouldParseExtensionRequest() {
        final ExtensionRequestData data = ExtensionRequestData
                .parseExtensionRequest("permessage-deflate; client_max_window_bits=15; server_no_context_takeover");
        assertEquals("permessage-deflate", data.getExtensionName(), "Extension name");
        assertEquals("15", data.getParameters().get("client_max_window_bits"), "Extension kv parameter");
        assertTrue(data.getParameters().containsKey("server_no_context_takeover"), "Extension flag parameter");
    }

    private static void shouldMatchProtocolHeader() {
        final Protocol protocol = new Protocol("chat");
        assertTrue(protocol.acceptProvidedProtocol("superchat, chat"), "Protocol negotiation");
        assertEquals("chat", protocol.copyInstance().getProvidedProtocol(), "Protocol copy");
        assertTrue(protocol.equals(new Protocol("chat")), "Protocol equality");
    }

    private static void shouldBuildCloseFramePayload() throws Exception {
        final CloseFrame closeFrame = new CloseFrame();
        closeFrame.setCode(1001);
        closeFrame.setReason("going away");
        closeFrame.updatePayload();
        assertTrue(closeFrame.getPayloadData().remaining() > 2, "Close frame has code and reason payload");
    }

    private static void shouldEncodeAndDecodeBase64() {
        final String encoded = Base64.encodeBytes("abc".getBytes(StandardCharsets.UTF_8));
        assertEquals("abc", new String(Base64.decode(encoded), StandardCharsets.UTF_8), "Base64 roundtrip");
    }

    private static void shouldCopyByteBuffer() {
        final ByteBuffer source = ByteBuffer.wrap(new byte[] {1, 2, 3});
        final ByteBuffer copy = ByteBufferUtils.copyOf(source);
        source.put(0, (byte) 9);
        assertEquals("1", Byte.toString(copy.get(0)), "ByteBuffer copy isolation");
        assertEquals("0", Integer.toString(ByteBufferUtils.getEmptyByteBuffer().remaining()), "Empty byte buffer");
    }

    private static void assertEquals(final String expected, final String actual, final String context) {
        if (!expected.equals(actual)) {
            throw new AssertionError(context + " expected=" + expected + " actual=" + actual);
        }
    }

    private static void assertTrue(final boolean condition, final String context) {
        if (!condition) {
            throw new AssertionError(context + " expected=true actual=false");
        }
    }
}

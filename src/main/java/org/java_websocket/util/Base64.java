package org.java_websocket.util;

public final class Base64 {

    private Base64() {
    }

    public static String encodeBytes(final byte[] input) {
        return java.util.Base64.getEncoder().encodeToString(input);
    }

    public static byte[] decode(final String input) {
        return java.util.Base64.getDecoder().decode(input);
    }
}

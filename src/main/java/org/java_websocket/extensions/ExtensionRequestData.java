package org.java_websocket.extensions;

import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;

public class ExtensionRequestData {

    private final String extensionName;
    private final Map<String, String> parameters;

    public ExtensionRequestData(final String extensionName, final Map<String, String> parameters) {
        this.extensionName = extensionName;
        this.parameters = new LinkedHashMap<>(parameters);
    }

    public String getExtensionName() {
        return extensionName;
    }

    public Map<String, String> getParameters() {
        return Collections.unmodifiableMap(parameters);
    }

    public static ExtensionRequestData parseExtensionRequest(final String input) {
        final String[] pieces = input.split(";");
        final Map<String, String> parsed = new LinkedHashMap<>();
        for (int index = 1; index < pieces.length; index++) {
            final String token = pieces[index].trim();
            if (token.isEmpty()) {
                continue;
            }
            final String[] keyValue = token.split("=", 2);
            if (keyValue.length == 1) {
                parsed.put(keyValue[0], "");
            } else {
                parsed.put(keyValue[0].trim(), keyValue[1].trim());
            }
        }
        return new ExtensionRequestData(pieces[0].trim(), parsed);
    }
}

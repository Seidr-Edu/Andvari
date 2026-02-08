# Assumptions

1. The reconstruction is delivered in slices; current code covers codec + handshake + protocol/extension primitives before full socket orchestration.
2. Current frame translation intentionally handles only single-frame unmasked text payloads (<=125 bytes) while the broader frame matrix will be expanded in later slices.
3. Java 21 is used for compatibility and stable toolchain behavior in this environment.
4. The `Sec-WebSocket-Key` default used in client post-processing is deterministic for test repeatability.

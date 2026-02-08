# java-websocket-reconstruction

This repository reconstructs core parts of the PlantUML-described `org.java_websocket` library in iterative vertical slices.

## Implemented so far

- RFC6455 text frame encode/decode baseline (`Draft_6455`, `Framedata*`, `TextFrame`)
- Handshake model and builders (`ClientHandshake*`, `ServerHandshake*`, `HandshakedataImpl1`)
- Handshake serialization/parsing (`HandshakeParser`, `Draft_6455#createHandshake`, `Draft_6455#translateHandshake`)
- Server-side handshake acceptance and response generation (`Sec-WebSocket-Accept`)
- Core protocol/extension primitives (`Protocol`, `IProtocol`, `DefaultExtension`, `ExtensionRequestData`)
- Additional frame types including `CloseFrame`
- Utility helpers (`Charsetfunctions`, `Base64`, `ByteBufferUtils`)
- Runnable example (`EchoCodecMain`) and deterministic test runner (`TestMain`)

## Commands

- `make build`
- `make test`
- `make lint`
- `make format`
- `make run`

#!/usr/bin/env bash
set -euo pipefail
gradle --no-daemon classes
java -cp build/classes/java/main org.java_websocket.example.EchoCodecMain

plugins {
    java
}

group = "org.java_websocket"
version = "1.0.0"

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(21))
    }
}

tasks.register("spotlessApply") {
    group = "formatting"
    description = "No-op formatter task in offline environment."
}

tasks.register("bootRun") {
    group = "application"
    description = "No-op run task for library reconstruction."
}

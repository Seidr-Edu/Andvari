# Assumptions

1. The provided PlantUML describes API surface and package structure, not behavioral internals, because method bodies and sequence flows are not defined.
2. In an offline environment, external formatting plugins may be unavailable; `spotlessApply` is implemented as a no-op Gradle task to preserve command compatibility.
3. No REST endpoints or Spring Boot runtime are included because the UML models a reusable WebSocket library API rather than a web application.
4. Inner-class notation using `$` in UML is represented as Java nested static classes.

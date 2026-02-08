# Java WebSocket UML Reconstruction

This repository reconstructs the Java package and type surface defined by `Java-WebSocket.puml`.

## Requirements
- Java 21+

## Commands
- Format: `./gradlew spotlessApply`
- Lint + checks: `./gradlew check`
- Test: `./gradlew test`
- Build: `./gradlew clean build`
- Run compatibility task: `./gradlew bootRun`

## Notes
- This diagram models library APIs/classes rather than REST endpoints.
- See `docs/ASSUMPTIONS.md` for interpretation decisions.

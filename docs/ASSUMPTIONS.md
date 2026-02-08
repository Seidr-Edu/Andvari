# Assumptions

- Android-only dependencies (`Context`, `Handler`, `Message`, `SQLiteDatabase`) were modeled as lightweight JVM-compatible classes to keep behavior deterministic in a server/runtime-neutral Java environment.
- `NoOpsDbHelper` returns a synthetic `DownloadModel` for `find` to avoid null contracts while still representing disabled persistence behavior.
- Redirect handling hook exists (`Utils.getRedirectedConnectionIfAny`) but currently returns the supplied client because the UML does not define redirect policy details.
- Download execution writes to `*.temp` then renames on success, and supports pause/cancel transitions via request status checks.
- `bootRun` is provided as a Gradle JavaExec task that starts the application entrypoint and initializes the downloader system.

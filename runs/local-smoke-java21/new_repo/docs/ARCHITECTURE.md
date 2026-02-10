# Architecture

## Modules

- `com.andvari.recon.DiagramSummary`: core logic that computes class and relationship counts from PlantUML text.
- `com.andvari.recon.DiagramSummaryTest`: JUnit 5 unit test validating parser behavior.

## Flow

1. Read PlantUML lines.
2. Count class declarations and relationship markers.
3. Produce a human-readable summary string.

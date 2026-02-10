#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <diagram_path> <target_repo_dir>" >&2
  exit 1
fi

DIAGRAM_PATH="$1"
TARGET_DIR="$2"

mkdir -p "$TARGET_DIR"

# Read diagram metadata for traceability in generated docs.
DIAGRAM_NAME="$(basename "$DIAGRAM_PATH")"
DIAGRAM_TITLE="$(awk '/^title /{sub(/^title /, ""); print; exit}' "$DIAGRAM_PATH" 2>/dev/null || true)"
if [[ -z "${DIAGRAM_TITLE}" ]]; then
  DIAGRAM_TITLE="Untitled diagram"
fi

mkdir -p "$TARGET_DIR/src/main/java/com/andvari/recon" \
         "$TARGET_DIR/src/test/java/com/andvari/recon" \
         "$TARGET_DIR/docs"

cat > "$TARGET_DIR/pom.xml" <<'POM'
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.andvari</groupId>
    <artifactId>reconstructed-repo</artifactId>
    <version>1.0.0</version>

    <properties>
        <maven.compiler.release>25</maven.compiler.release>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
        <junit.jupiter.version>5.12.1</junit.jupiter.version>
    </properties>

    <dependencies>
        <dependency>
            <groupId>org.junit.jupiter</groupId>
            <artifactId>junit-jupiter</artifactId>
            <version>${junit.jupiter.version}</version>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-surefire-plugin</artifactId>
                <version>3.5.2</version>
                <configuration>
                    <useModulePath>false</useModulePath>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
POM

cat > "$TARGET_DIR/src/main/java/com/andvari/recon/DiagramSummary.java" <<'EOF_JAVA'
package com.andvari.recon;

import java.util.List;
import java.util.Objects;

public final class DiagramSummary {
    private final String diagramName;
    private final String title;
    private final int classCount;
    private final int relationshipCount;

    public DiagramSummary(String diagramName, String title, int classCount, int relationshipCount) {
        this.diagramName = Objects.requireNonNull(diagramName, "diagramName must not be null");
        this.title = Objects.requireNonNull(title, "title must not be null");
        this.classCount = classCount;
        this.relationshipCount = relationshipCount;
    }

    public String render() {
        return "%s (%s): %d classes, %d relationships".formatted(title, diagramName, classCount, relationshipCount);
    }

    public static DiagramSummary fromPlantUml(String diagramName, String title, List<String> lines) {
        int classCount = (int) lines.stream().filter(line -> line.trim().startsWith("class ")).count();
        int relationshipCount = (int) lines.stream()
                .filter(line -> line.contains("--") || line.contains("..") || line.contains("<|"))
                .count();
        return new DiagramSummary(diagramName, title, classCount, relationshipCount);
    }
}
EOF_JAVA

cat > "$TARGET_DIR/src/test/java/com/andvari/recon/DiagramSummaryTest.java" <<'EOF_TEST'
package com.andvari.recon;

import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;

class DiagramSummaryTest {

    @Test
    void summarizesPlantUmlClassesAndRelationships() {
        DiagramSummary summary = DiagramSummary.fromPlantUml(
                "diagram.puml",
                "Sample",
                List.of(
                        "@startuml",
                        "class Runner",
                        "class Worker",
                        "Runner --> Worker",
                        "@enduml"
                ));

        assertEquals("Sample (diagram.puml): 2 classes, 1 relationships", summary.render());
    }
}
EOF_TEST

cat > "$TARGET_DIR/README.md" <<EOF_README
# Reconstructed Java Repository

This repository was generated from diagram source \`docs/$DIAGRAM_NAME\`.

## Build and test

Run:

\`\`\`bash
mvn -q test
\`\`\`
EOF_README

cat > "$TARGET_DIR/docs/ASSUMPTIONS.md" <<EOF_ASSUMPTIONS
# Assumptions

- The source diagram is \`docs/$DIAGRAM_NAME\` and has title "$DIAGRAM_TITLE".
- The mock reconstruction demonstrates a deterministic parser summary component instead of a full domain reconstruction.
- Java 25 is targeted via Maven compiler release configuration.
EOF_ASSUMPTIONS

cat > "$TARGET_DIR/docs/ARCHITECTURE.md" <<'EOF_ARCH'
# Architecture

## Modules

- `com.andvari.recon.DiagramSummary`: core logic that computes class and relationship counts from PlantUML text.
- `com.andvari.recon.DiagramSummaryTest`: JUnit 5 unit test validating parser behavior.

## Flow

1. Read PlantUML lines.
2. Count class declarations and relationship markers.
3. Produce a human-readable summary string.
EOF_ARCH

cp "$DIAGRAM_PATH" "$TARGET_DIR/docs/$DIAGRAM_NAME"

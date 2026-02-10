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

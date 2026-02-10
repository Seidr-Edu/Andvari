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

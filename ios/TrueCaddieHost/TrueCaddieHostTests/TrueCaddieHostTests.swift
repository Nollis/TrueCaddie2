//
//  TrueCaddieHostTests.swift
//  TrueCaddieHostTests
//
//  Created by user273008 on 5/12/26.
//

import Testing
import TrueCaddieDomain
@testable import TrueCaddieHost

struct TrueCaddieHostTests {

    @Test func loadsBundledKungsbackaCourse() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()

        #expect(bundle.courseName == "Kungsbacka Nya")
        #expect(bundle.bundleVersion == "kungsbacka-nya.v1.foundation")
        #expect(bundle.holes.count == 9)
    }

    @Test func parFiveInspectorScenariosIncludeLayupLeave() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let hole = try #require(bundle.holes.first(where: { $0.holeNumber == 1 }))
        let scenarios = HoleInspectorModel.makeShotStateScenarios(
            for: hole,
            courseId: bundle.courseId,
            playerContext: .pilotSample,
            roundContext: .pilotSample
        )

        #expect(scenarios.contains(where: { $0.id == "layup" }))
        #expect(scenarios.first?.id == "default")
    }

    @Test func selectedLayupScenarioProducesUnifiedNextShotPacket() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let hole = try #require(bundle.holes.first(where: { $0.holeNumber == 1 }))
        let scenarios = HoleInspectorModel.makeShotStateScenarios(
            for: hole,
            courseId: bundle.courseId,
            playerContext: .pilotSample,
            roundContext: .pilotSample
        )
        let layupScenario = try #require(scenarios.first(where: { $0.id == "layup" }))
        let packet = HoleInspectorModel.nextShotRecommendation(
            for: hole,
            courseId: bundle.courseId,
            playerContext: .pilotSample,
            roundContext: .pilotSample,
            selectedScenarioId: layupScenario.id
        )

        #expect(packet?.shotPhase == "approach")
        #expect(packet?.shotNumber == 3)
        #expect(packet?.remainingDistanceM == 100)
        #expect(packet?.headline == "PW to Center green")
        #expect(packet?.executionNote == "PW carry 118m fits a center green number with 5m/s helping wind.")
    }

    @Test func voicePreviewUsesDeterministicPacketFields() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let hole = try #require(bundle.holes.first(where: { $0.holeNumber == 1 }))
        let packet = try #require(
            HoleInspectorModel.nextShotRecommendation(
                for: hole,
                courseId: bundle.courseId,
                playerContext: .pilotSample,
                roundContext: .pilotSample,
                selectedScenarioId: "layup"
            )
        )

        let voicePreview = HoleInspectorModel.voicePreviewText(for: packet)

        #expect(
            voicePreview ==
            "PW to Center green. PW carry 118m fits a center green number with 5m/s helping wind. Favor left. Avoid right."
        )
    }

    @Test func voicePreviewIncludesFallbackWhenPresent() {
        let packet = NextShotRecommendationPacket(
            courseId: "course",
            holeId: "hole-1",
            holeNumber: 1,
            shotPhase: "layup",
            recommendationType: "layup",
            shotNumber: 2,
            remainingDistanceM: 180,
            lie: .fairway,
            strategyPreference: "balanced",
            targetLabel: "Right-center layup shelf",
            recommendedClub: "7I",
            clubCarryDistanceM: 150,
            shotDistanceM: 150,
            plannedLeaveDistanceM: 100,
            preferredMissDirection: "left",
            avoidDirection: "right",
            riskLevel: "medium",
            confidenceBand: "medium",
            confidenceScore: 0.8,
            primaryReason: "Keep the next wedge simple.",
            supportingReason: "7I puts the ball on the shelf without bringing the front bunker in.",
            hazardSummary: [],
            headline: "7I to Right-center layup shelf",
            executionNote: "7I puts the ball on the shelf without bringing the front bunker in.",
            missNote: "Favor left. Avoid right.",
            fallbackNote: "If it's not on, leave yourself about 100m in."
        )

        #expect(
            HoleInspectorModel.voicePreviewText(for: packet) ==
            "7I to Right-center layup shelf. 7I puts the ball on the shelf without bringing the front bunker in. Favor left. Avoid right. If it's not on, leave yourself about 100m in."
        )
    }

    @Test func inspectorTabsAreOrderedForPrimaryUseFirst() {
        #expect(HoleInspectorModel.HoleInspectorTab.allCases == [.overview, .strategy, .debug])
        #expect(HoleInspectorModel.HoleInspectorTab.overview.title == "Overview")
        #expect(HoleInspectorModel.HoleInspectorTab.strategy.title == "Strategy")
        #expect(HoleInspectorModel.HoleInspectorTab.debug.title == "Debug")
    }

    @Test func inspectorSectionsGroupHighSignalContentAheadOfDebugData() {
        #expect(
            HoleInspectorModel.sections(for: .overview) ==
            [.holeSketch, .nextShotRecommendation, .shotState]
        )
        #expect(
            HoleInspectorModel.sections(for: .strategy) ==
            [.liveRoundControls, .playerContext, .roundContext, .teeTargetCorridors, .preferredMiss, .hazardSeverity]
        )
        #expect(
            HoleInspectorModel.sections(for: .debug) ==
            [.bundle, .hole, .green, .tees, .featureTypes, .featureHighlights, .overlayContainers, .qualityNotes, .provenance]
        )
    }

    @Test func roundOverridesCanDisableWindAndChangeStrategy() {
        let overrides = HoleInspectorModel.RoundOverrideState(
            teeSetId: "white",
            strategyPreference: .conservative,
            windEnabled: false,
            windDirection: .hurting,
            windSpeedMps: 7
        )

        let effectiveRoundContext = HoleInspectorModel.makeEffectiveRoundContext(
            from: overrides,
            baseRoundContext: .pilotSample,
            hole: nil
        )

        #expect(effectiveRoundContext.teeSetId == "white")
        #expect(effectiveRoundContext.teeSetName == "White")
        #expect(effectiveRoundContext.strategyPreference == .conservative)
        #expect(effectiveRoundContext.wind == nil)
    }

    @Test func layupPacketRespondsToRoundOverrides() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let hole = try #require(bundle.holes.first(where: { $0.holeNumber == 1 }))
        let roundOverrides = HoleInspectorModel.RoundOverrideState(
            teeSetId: "white",
            strategyPreference: .conservative,
            windEnabled: false,
            windDirection: .helping,
            windSpeedMps: 5
        )
        let effectiveRoundContext = HoleInspectorModel.makeEffectiveRoundContext(
            from: roundOverrides,
            baseRoundContext: .pilotSample,
            hole: hole
        )
        let packet = HoleInspectorModel.nextShotRecommendation(
            for: hole,
            courseId: bundle.courseId,
            playerContext: .pilotSample,
            roundContext: effectiveRoundContext,
            selectedScenarioId: "layup"
        )

        #expect(packet?.shotNumber == 3)
        #expect(packet?.remainingDistanceM == 110)
        #expect(packet?.strategyPreference == "conservative")
        #expect(packet?.executionNote == "PW carry 118m fits a center green number.")
    }
}

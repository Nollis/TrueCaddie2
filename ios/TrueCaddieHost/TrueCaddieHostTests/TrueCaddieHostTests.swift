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
}

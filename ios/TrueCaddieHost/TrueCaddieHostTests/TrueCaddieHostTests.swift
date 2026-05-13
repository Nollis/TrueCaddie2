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

    @Test func lowConfidenceGuidanceOnlyAppearsForLowBand() {
        #expect(
            HoleInspectorModel.confidenceGuidance(for: makePacket(confidenceBand: "low")) ==
            "Lower-confidence read. Confirm the picture and favor the stock outcome."
        )
        #expect(HoleInspectorModel.confidenceGuidance(for: makePacket(confidenceBand: "medium")) == nil)
    }

    @Test func recommendationPrimaryFactsStayCompact() {
        let facts = HoleInspectorModel.primaryFacts(for: makePacket())

        #expect(
            facts ==
            [
                .init(label: "Shot", value: "Layup 150 m"),
                .init(label: "Risk", value: "Medium"),
                .init(label: "Plan", value: "Balanced"),
                .init(label: "Leave", value: "100 m")
            ]
        )
    }

    @Test func recommendationDebugFactsCollectSecondaryPacketDetails() {
        let facts = HoleInspectorModel.debugFacts(for: makePacket())

        #expect(facts.contains(.init(label: "Club", value: "7I • carry 150 m")))
        #expect(facts.contains(.init(label: "Miss", value: "Favor left, avoid right")))
        #expect(facts.contains(.init(label: "Fallback", value: "If it's not on, leave yourself about 100m in.")))
        #expect(facts.contains(.init(label: "Hazards", value: "Bunker left")))
    }

    @Test func roundPreviewUsesFirstHoleAndUnifiedPacket() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let preview = try #require(
            HostRoundPreviewModel.firstHolePreview(
                bundle: bundle,
                playerContext: .pilotSample,
                roundContext: .pilotSample
            )
        )

        #expect(preview.holeNumber == 1)
        #expect(preview.par == 5)
        #expect(preview.scenarioName == "Fairway result")
        #expect(preview.packet.headline == "PW to Lay up for wedge number")
    }

    @Test func roundPreviewVoiceCopyComesFromUnifiedPacket() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let preview = try #require(
            HostRoundPreviewModel.firstHolePreview(
                bundle: bundle,
                playerContext: .pilotSample,
                roundContext: .pilotSample
            )
        )

        #expect(
            preview.voicePreview ==
            HoleInspectorModel.voicePreviewText(for: preview.packet)
        )
    }

    @Test func roundPreviewCanBuildSelectedScenario() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let preview = try #require(
            HostRoundPreviewModel.preview(
                bundle: bundle,
                playerContext: .pilotSample,
                roundContext: .pilotSample,
                holeNumber: 1,
                planMode: .stockNextShot,
                selectedScenarioId: "rough"
            )
        )

        #expect(preview.holeNumber == 1)
        #expect(preview.scenarioName == "Missed right rough")
        #expect(preview.packet.lie == .rough)
    }

    @Test func roundPreviewCanBuildDifferentHole() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let preview = try #require(
            HostRoundPreviewModel.preview(
                bundle: bundle,
                playerContext: .pilotSample,
                roundContext: .pilotSample,
                holeNumber: 7,
                planMode: .stockNextShot,
                selectedScenarioId: ""
            )
        )

        #expect(preview.holeNumber == 7)
        #expect(preview.packet.holeNumber == 7)
    }

    @Test func roundPreviewRespondsToRoundOverrides() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let hole = try #require(bundle.holes.first(where: { $0.holeNumber == 1 }))
        let effectiveRoundContext = HoleInspectorModel.makeEffectiveRoundContext(
            from: .init(
                teeSetId: "white",
                strategyPreference: .conservative,
                windEnabled: false,
                windDirection: .helping,
                windSpeedMps: 5
            ),
            baseRoundContext: .pilotSample,
            hole: hole
        )
        let preview = try #require(
            HostRoundPreviewModel.preview(
                bundle: bundle,
                playerContext: .pilotSample,
                roundContext: effectiveRoundContext,
                holeNumber: 1,
                planMode: .stockNextShot,
                selectedScenarioId: "layup"
            )
        )

        #expect(preview.packet.remainingDistanceM == 110)
        #expect(preview.packet.strategyPreference == "conservative")
        #expect(preview.voicePreview == "PW to Center green. PW carry 118m fits a center green number.")
    }

    @Test func roundPreviewsCoverEachHoleWithUnifiedPackets() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let previews = HostRoundPreviewModel.roundPreviews(
            bundle: bundle,
            playerContext: .pilotSample,
            roundContext: .pilotSample,
            planMode: .stockNextShot
        )

        #expect(previews.count == bundle.holes.count)
        #expect(previews.first?.holeNumber == 1)
        #expect(previews.last?.holeNumber == 9)
        #expect(previews.allSatisfy { !$0.packet.headline.isEmpty })
    }

    @Test func roundPreviewsRespectSelectedHoleOrder() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let previews = HostRoundPreviewModel.roundPreviews(
            bundle: bundle,
            playerContext: .pilotSample,
            roundContext: .pilotSample,
            planMode: .stockNextShot
        )
        let holeSeven = try #require(previews.first(where: { $0.holeNumber == 7 }))

        #expect(holeSeven.par == 5)
        #expect(holeSeven.packet.holeNumber == 7)
    }

    @Test func teePlanModeUsesOpeningShotContext() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let preview = try #require(
            HostRoundPreviewModel.preview(
                bundle: bundle,
                playerContext: .pilotSample,
                roundContext: .pilotSample,
                holeNumber: 4,
                planMode: .teePlan,
                selectedScenarioId: ""
            )
        )

        #expect(preview.scenarioName == "Tee shot")
        #expect(preview.packet.shotNumber == 1)
        #expect(preview.packet.lie == .tee)
    }

    @Test func layupViewModePrefersLayupScenarioOnParFive() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let preview = try #require(
            HostRoundPreviewModel.preview(
                bundle: bundle,
                playerContext: .pilotSample,
                roundContext: .pilotSample,
                holeNumber: 1,
                planMode: .layupView,
                selectedScenarioId: ""
            )
        )

        #expect(preview.scenarioName == "Layup leave")
        #expect(preview.packet.shotNumber == 3)
    }

    @Test func liveHoleStateOverridesSyntheticScenario() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let preview = try #require(
            HostRoundPreviewModel.preview(
                bundle: bundle,
                playerContext: .pilotSample,
                roundContext: .pilotSample,
                holeNumber: 4,
                planMode: .stockNextShot,
                selectedScenarioId: "",
                roundState: RoundState(
                    courseId: bundle.courseId,
                    holeStates: [
                        .init(
                            holeNumber: 4,
                            status: .inProgress,
                            shotStateContext: ShotStateContext(
                                shotNumber: 3,
                                remainingDistanceM: 96,
                                lie: .fairway
                            )
                        )
                    ]
                )
            )
        )

        #expect(preview.scenarioName == "Live state")
        #expect(preview.packet.shotNumber == 3)
        #expect(preview.packet.remainingDistanceM == 96)
    }

    @Test func roundPreviewsShowLiveStateWhenHoleHasStarted() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let previews = HostRoundPreviewModel.roundPreviews(
            bundle: bundle,
            playerContext: .pilotSample,
            roundContext: .pilotSample,
            planMode: .stockNextShot,
            roundState: RoundState(
                courseId: bundle.courseId,
                holeStates: [
                    .init(
                        holeNumber: 1,
                        status: .inProgress,
                        shotStateContext: ShotStateContext(
                            shotNumber: 3,
                            remainingDistanceM: 88,
                            lie: .fairway
                        )
                    )
                ]
            )
        )
        let holeOne = try #require(previews.first(where: { $0.holeNumber == 1 }))

        #expect(holeOne.scenarioName == "Live state")
        #expect(holeOne.packet.shotNumber == 3)
        #expect(holeOne.packet.remainingDistanceM == 88)
    }

    @Test func currentHolePrefersSavedSelectionWhenStillValid() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()

        let holeNumber = HostRoundProgressModel.currentHoleNumber(
            bundle: bundle,
            roundState: RoundState(courseId: bundle.courseId, holeStates: []),
            preferredHoleNumber: 4
        )

        #expect(holeNumber == 4)
    }

    @Test func currentHoleFallsBackToFirstInProgressHole() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()

        let holeNumber = HostRoundProgressModel.currentHoleNumber(
            bundle: bundle,
            roundState: RoundState(
                courseId: bundle.courseId,
                holeStates: [
                    .init(
                        holeNumber: 3,
                        status: .finished,
                        shotStateContext: nil
                    ),
                    .init(
                        holeNumber: 5,
                        status: .inProgress,
                        shotStateContext: ShotStateContext(
                            shotNumber: 2,
                            remainingDistanceM: 140,
                            lie: .fairway
                        )
                    )
                ]
            ),
            preferredHoleNumber: 42
        )

        #expect(holeNumber == 5)
    }

    @Test func currentHoleDoesNotResumeFinishedPreferredHole() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()

        let holeNumber = HostRoundProgressModel.currentHoleNumber(
            bundle: bundle,
            roundState: RoundState(
                courseId: bundle.courseId,
                holeStates: [
                    .init(holeNumber: 4, status: .finished, shotStateContext: nil, strokesTaken: 5),
                    .init(
                        holeNumber: 6,
                        status: .inProgress,
                        shotStateContext: ShotStateContext(
                            shotNumber: 2,
                            remainingDistanceM: 131,
                            lie: .fairway
                        ),
                        strokesTaken: 1
                    )
                ]
            ),
            preferredHoleNumber: 4
        )

        #expect(holeNumber == 6)
    }

    @Test func nextUnfinishedHoleSkipsFinishedHolesAndWraps() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()

        let nextHoleNumber = HostRoundProgressModel.nextUnfinishedHoleNumber(
            after: 4,
            bundle: bundle,
            roundState: RoundState(
                courseId: bundle.courseId,
                holeStates: [
                    .init(holeNumber: 4, status: .finished, shotStateContext: nil),
                    .init(holeNumber: 5, status: .finished, shotStateContext: nil),
                    .init(
                        holeNumber: 6,
                        status: .inProgress,
                        shotStateContext: ShotStateContext(
                            shotNumber: 2,
                            remainingDistanceM: 132,
                            lie: .fairway
                        )
                    )
                ]
            )
        )

        #expect(nextHoleNumber == 6)
    }

    @Test func roundSummaryReflectsFinishedScoreAndCurrentHoleStatus() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let summary = HostRoundProgressModel.summary(
            bundle: bundle,
            roundState: RoundState(
                courseId: bundle.courseId,
                holeStates: [
                    .init(
                        holeNumber: 1,
                        status: .finished,
                        shotStateContext: ShotStateContext(
                            shotNumber: 5,
                            remainingDistanceM: 0,
                            lie: .fairway
                        ),
                        strokesTaken: 5
                    ),
                    .init(
                        holeNumber: 2,
                        status: .inProgress,
                        shotStateContext: ShotStateContext(
                            shotNumber: 2,
                            remainingDistanceM: 146,
                            lie: .fairway
                        ),
                        strokesTaken: 1
                    )
                ]
            ),
            currentHoleNumber: 2
        )

        #expect(summary.currentHoleNumber == 2)
        #expect(summary.currentHoleHeader == "Current hole 2")
        #expect(summary.progressLabel == "1 of 9 complete")
        #expect(summary.totalsHeader == "Through 1: E")
    }

    @Test func roundSummaryShowsNotStartedWhenNoHoleHasBegun() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let summary = HostRoundProgressModel.summary(
            bundle: bundle,
            roundState: RoundState(courseId: bundle.courseId, holeStates: []),
            currentHoleNumber: 1
        )

        #expect(summary.currentHoleHeader == "Current hole 1")
        #expect(summary.progressLabel == "0 of 9 complete")
        #expect(summary.totalsHeader == "Round ready")
    }

    @Test func roundSummaryShowsPositiveTotalRelativeToPar() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let summary = HostRoundProgressModel.summary(
            bundle: bundle,
            roundState: RoundState(
                courseId: bundle.courseId,
                holeStates: [
                    .init(
                        holeNumber: 1,
                        status: .finished,
                        shotStateContext: nil,
                        strokesTaken: 8
                    ),
                    .init(
                        holeNumber: 2,
                        status: .finished,
                        shotStateContext: nil,
                        strokesTaken: 4
                    )
                ]
            ),
            currentHoleNumber: 3
        )

        #expect(summary.totalsHeader == "Through 2: +4")
    }

    @Test func roundSummaryShowsFinalStateWhenAllHolesAreFinished() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let summary = HostRoundProgressModel.summary(
            bundle: bundle,
            roundState: RoundState(
                courseId: bundle.courseId,
                holeStates: bundle.holes.map { hole in
                    .init(
                        holeNumber: hole.holeNumber,
                        status: .finished,
                        shotStateContext: nil,
                        strokesTaken: hole.par
                    )
                }
            ),
            currentHoleNumber: 9
        )

        #expect(summary.currentHoleHeader == "Round complete")
        #expect(summary.totalsHeader == "Final: E")
        #expect(summary.isRoundComplete == true)
    }

    @Test func scorecardEntriesOnlyIncludeStartedHolesAndKeepHoleOrder() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let entries = HostRoundProgressModel.scorecardEntries(
            bundle: bundle,
            roundState: RoundState(
                courseId: bundle.courseId,
                holeStates: [
                    .init(
                        holeNumber: 3,
                        status: .finished,
                        shotStateContext: nil,
                        strokesTaken: 5
                    ),
                    .init(
                        holeNumber: 1,
                        status: .inProgress,
                        shotStateContext: ShotStateContext(
                            shotNumber: 2,
                            remainingDistanceM: 188,
                            lie: .fairway
                        ),
                        strokesTaken: 1
                    )
                ]
            ),
            currentHoleNumber: 1
        )

        #expect(entries.map(\.holeNumber) == [1, 3])
        #expect(entries[0].isCurrentHole == true)
        #expect(entries[0].statusLabel == "In progress")
        #expect(entries[1].statusLabel == "Finished")
        #expect(entries[1].isFinished == true)
    }

    @Test func scorecardEntriesFormatStrokesAndRelativeToPar() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let entries = HostRoundProgressModel.scorecardEntries(
            bundle: bundle,
            roundState: RoundState(
                courseId: bundle.courseId,
                holeStates: [
                    .init(
                        holeNumber: 1,
                        status: .finished,
                        shotStateContext: nil,
                        strokesTaken: 5
                    ),
                    .init(
                        holeNumber: 2,
                        status: .finished,
                        shotStateContext: nil,
                        strokesTaken: 2
                    )
                ]
            ),
            currentHoleNumber: 2
        )

        #expect(entries[0].strokesLabel == "5")
        #expect(entries[0].relativeToParLabel == "E")
        #expect(entries[0].rawStrokesTaken == 5)
        #expect(entries[1].strokesLabel == "2")
        #expect(entries[1].relativeToParLabel == "-1")
    }

    @Test func shotResultDraftDefaultsTeeResultToFairwayLie() {
        let draft = HostRoundProgressModel.makeShotResultDraft(
            from: ShotStateContext(
                shotNumber: 1,
                remainingDistanceM: 352,
                lie: .tee
            )
        )

        #expect(draft.currentShotNumber == 1)
        #expect(draft.resultingLie == .fairway)
        #expect(draft.remainingDistanceM == 352)
        #expect(draft.holedOut == false)
    }

    @Test func shotResultDraftAdvancesToNextShotState() {
        let result = HostRoundProgressModel.applyShotResultDraft(
            .init(
                currentShotNumber: 2,
                resultingLie: .rough,
                remainingDistanceM: 141,
                holedOut: false
            )
        )

        #expect(
            result == .advance(
                ShotStateContext(
                    shotNumber: 3,
                    remainingDistanceM: 141,
                    lie: .rough
                )
            )
        )
    }

    @Test func shotResultDraftCanHoleOutCurrentShot() {
        let result = HostRoundProgressModel.applyShotResultDraft(
            .init(
                currentShotNumber: 4,
                resultingLie: .fairway,
                remainingDistanceM: 0,
                holedOut: true
            )
        )

        #expect(result == .holeOut(strokesTaken: 4))
    }

    @Test func conversationParsesSaferPlayAndShotResultIntents() {
        #expect(HostCaddieSession.interpret("safe play") == .askForSaferPlay)
        #expect(HostCaddieSession.interpret("rough 128") == .reportShotResult(lie: .rough, remainingDistanceM: 128))
        #expect(HostCaddieSession.interpret("repeat that") == .repeatLastGuidance)
    }

    @Test func conversationShotResultAdvancesRoundStateAndRepliesFromNewContext() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let outcome = try #require(
            HostCaddieSession.respond(
                to: .init(
                    utterance: "rough 128",
                    context: .init(
                        bundle: bundle,
                        playerContext: .pilotSample,
                        roundContext: .pilotSample,
                        selectedHoleNumber: 1,
                        planMode: .stockNextShot,
                        roundState: RoundState(
                            courseId: bundle.courseId,
                            holeStates: [
                                .init(
                                    holeNumber: 1,
                                    status: .inProgress,
                                    shotStateContext: ShotStateContext(
                                        shotNumber: 2,
                                        remainingDistanceM: 220,
                                        lie: .fairway
                                    ),
                                    strokesTaken: 1
                                )
                            ]
                        )
                    )
                )
            )
        )

        #expect(outcome.roundState.holeState(for: 1)?.shotStateContext?.shotNumber == 3)
        #expect(outcome.roundState.holeState(for: 1)?.shotStateContext?.remainingDistanceM == 128)
        #expect(outcome.roundState.holeState(for: 1)?.shotStateContext?.lie == .rough)
        #expect(outcome.assistantReply.contains("From rough at 128m"))
    }

    @Test func conversationHoleOutFinishesHoleAndMovesToNextHole() throws {
        let bundle = try HostCourseBundleStore.loadKungsbackaNya()
        let outcome = try #require(
            HostCaddieSession.respond(
                to: .init(
                    utterance: "holed out",
                    context: .init(
                        bundle: bundle,
                        playerContext: .pilotSample,
                        roundContext: .pilotSample,
                        selectedHoleNumber: 1,
                        planMode: .stockNextShot,
                        roundState: RoundState(
                            courseId: bundle.courseId,
                            holeStates: [
                                .init(
                                    holeNumber: 1,
                                    status: .inProgress,
                                    shotStateContext: ShotStateContext(
                                        shotNumber: 4,
                                        remainingDistanceM: 3,
                                        lie: .fairway
                                    ),
                                    strokesTaken: 3
                                )
                            ]
                        )
                    )
                )
            )
        )

        #expect(outcome.roundState.holeState(for: 1)?.status == .finished)
        #expect(outcome.roundState.holeState(for: 1)?.strokesTaken == 4)
        #expect(outcome.selectedHoleNumber == 2)
        #expect(outcome.assistantReply.contains("Current hole 2"))
    }

    private func makePacket(confidenceBand: String = "medium") -> NextShotRecommendationPacket {
        NextShotRecommendationPacket(
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
            confidenceBand: confidenceBand,
            confidenceScore: 0.8,
            primaryReason: "Keep the next wedge simple.",
            supportingReason: "7I puts the ball on the shelf without bringing the front bunker in.",
            hazardSummary: ["Bunker left"],
            headline: "7I to Right-center layup shelf",
            executionNote: "7I puts the ball on the shelf without bringing the front bunker in.",
            missNote: "Favor left. Avoid right.",
            fallbackNote: "If it's not on, leave yourself about 100m in."
        )
    }
}

//
//  TrueCaddieHostUITests.swift
//  TrueCaddieHostUITests
//
//  Created by user273008 on 5/12/26.
//

import XCTest

final class TrueCaddieHostUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testStartsRoundFromVisibleCourseCatalog() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-truecaddie-ui-testing-location-denied"]
        app.launch()

        XCTAssertTrue(app.staticTexts["TrueCaddie"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Start Round"].waitForExistence(timeout: 2))

        app.buttons["Start Round"].tap()

        XCTAssertTrue(app.buttons["Enable microphone access"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}

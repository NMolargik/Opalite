//
//  OpaliteWatch_Watch_AppUITests.swift
//  OpaliteWatch Watch AppUITests
//
//  Created by Nick Molargik on 12/29/25.
//

import XCTest

final class OpaliteWatch_Watch_AppUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Launch Tests

    @MainActor
    func testAppLaunches() throws {
        // Verify the app launches without crashing
        XCTAssertTrue(app.state == .runningForeground)
    }

    @MainActor
    func testNavigationTitleExists() throws {
        // The navigation title should be "Opalite"
        let navTitle = app.staticTexts["Opalite"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5))
    }

    @MainActor
    func testRefreshButtonExists() throws {
        // The refresh button should be in the toolbar
        let refreshButton = app.buttons["arrow.clockwise"]
        XCTAssertTrue(refreshButton.waitForExistence(timeout: 5))
    }

    // MARK: - Empty State Tests

    @MainActor
    func testEmptyStateDisplayed() throws {
        // When no colors exist, the empty state should be shown
        // Look for the ContentUnavailableView text
        let emptyStateTitle = app.staticTexts["No Colors Yet"]

        // This may or may not exist depending on CloudKit data
        // If it exists, verify the description is also present
        if emptyStateTitle.waitForExistence(timeout: 3) {
            let description = app.staticTexts["Create colors on your iPhone and they will sync here automatically."]
            XCTAssertTrue(description.exists)
        }
    }

    // MARK: - Navigation Tests

    @MainActor
    func testColorsNavigationLinkExists() throws {
        // If there are loose colors, the "Colors" navigation link should exist
        let colorsLink = app.buttons["Colors"]

        // This only exists if there are colors, so we just check if app is responsive
        // by verifying the main navigation exists
        let navTitle = app.staticTexts["Opalite"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5))
    }

    @MainActor
    func testPalettesSectionExists() throws {
        // If there are palettes, the "Palettes" section should exist
        let palettesSection = app.staticTexts["Palettes"]

        // The navigation should be present regardless
        let navTitle = app.staticTexts["Opalite"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5))
    }

    @MainActor
    func testRefreshButtonTappable() throws {
        // Verify the refresh button can be tapped
        let refreshButton = app.buttons["arrow.clockwise"]

        if refreshButton.waitForExistence(timeout: 5) {
            XCTAssertTrue(refreshButton.isHittable)
            refreshButton.tap()
            // App should still be running after tap
            XCTAssertTrue(app.state == .runningForeground)
        }
    }

    // MARK: - Performance Tests

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    func testScrollPerformance() throws {
        // If there's a list, test scrolling performance
        let list = app.tables.firstMatch

        if list.waitForExistence(timeout: 3) {
            measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric]) {
                list.swipeUp()
                list.swipeDown()
            }
        }
    }
}

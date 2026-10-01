//
//  OpaliteWatch_Watch_AppUITestsLaunchTests.swift
//  OpaliteWatch Watch AppUITests
//
//  Created by Nick Molargik on 12/29/25.
//

import XCTest

final class OpaliteWatch_Watch_AppUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Verify the app launched successfully
        XCTAssertTrue(app.state == .runningForeground)

        // Capture launch screenshot
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testLaunchWithEmptyState() throws {
        let app = XCUIApplication()
        app.launch()

        // Wait for UI to settle
        let navTitle = app.staticTexts["Opalite"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5))

        // Capture the main view state
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Main View"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testLaunchAccessibility() throws {
        let app = XCUIApplication()
        app.launch()

        // Verify accessibility elements are present
        let navTitle = app.staticTexts["Opalite"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5))

        // The refresh button should be accessible
        let refreshButton = app.buttons["arrow.clockwise"]
        if refreshButton.waitForExistence(timeout: 3) {
            XCTAssertTrue(refreshButton.isEnabled)
        }

        // Capture accessibility state
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Accessibility Check"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

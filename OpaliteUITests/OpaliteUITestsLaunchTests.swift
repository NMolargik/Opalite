//
//  OpaliteUITestsLaunchTests.swift
//  OpaliteUITests
//
//  Created by Nick Molargik on 12/6/25.
//

import XCTest

final class OpaliteUITestsLaunchTests: XCTestCase {

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

        // Verify app launched successfully
        XCTAssertTrue(app.state == .runningForeground)

        // Capture launch screenshot
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testLaunchPortfolio() throws {
        let app = XCUIApplication()
        app.launch()

        // Navigate to Portfolio and screenshot
        let portfolioTab = app.tabBars.buttons["Portfolio"]
        if portfolioTab.exists {
            portfolioTab.tap()
            sleep(1)

            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "Portfolio Screen"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    @MainActor
    func testLaunchSearch() throws {
        let app = XCUIApplication()
        app.launch()

        // Navigate to Search and screenshot
        let searchTab = app.tabBars.buttons["Search"]
        if searchTab.exists {
            searchTab.tap()
            sleep(1)

            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "Search Screen"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    @MainActor
    func testLaunchSettings() throws {
        let app = XCUIApplication()
        app.launch()

        // Navigate to Settings and screenshot
        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.exists {
            settingsTab.tap()
            sleep(1)

            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "Settings Screen"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    @MainActor
    func testLaunchDarkMode() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "-UIUserInterfaceStyleForcedPresentation", "2"]
        app.launch()

        sleep(1)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Dark Mode Launch"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testLaunchLightMode() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "-UIUserInterfaceStyleForcedPresentation", "1"]
        app.launch()

        sleep(1)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Light Mode Launch"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testLaunchLandscape() throws {
        let app = XCUIApplication()
        app.launch()

        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(1)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Landscape Launch"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

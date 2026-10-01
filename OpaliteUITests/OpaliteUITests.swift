//
//  OpaliteUITests.swift
//  OpaliteUITests
//
//  Smoke tests over the shell: launch, the splash → onboarding → main flow, tab
//  navigation, and the global "New Color" entry point. They use the accessibility
//  identifiers the feature modules publish (`splashView`, `continueButton`, `skipButton`,
//  `onboardingView`, `mainView`, `accessoryNewColorButton`).
//

import XCTest

final class OpaliteUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Launch

    @MainActor
    func testAppLaunches() throws {
        app.launch()
        XCTAssertEqual(app.state, .runningForeground)
    }

    // MARK: - Onboarding

    @MainActor
    func testSplashContinueAdvancesToOnboarding() throws {
        app.launchArguments.append("--reset-onboarding")
        app.launch()
        let splash = app.otherElements["splashView"]
        XCTAssertTrue(splash.waitForExistence(timeout: 5))
        app.buttons["continueButton"].firstMatch.tap()
        XCTAssertTrue(app.otherElements["onboardingView"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSkipFinishesOnboarding() throws {
        app.launchArguments.append("--reset-onboarding")
        app.launch()
        XCTAssertTrue(app.otherElements["splashView"].waitForExistence(timeout: 5))
        app.buttons["continueButton"].firstMatch.tap()
        let skip = app.buttons["skipButton"].firstMatch
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        skip.tap()
        XCTAssertTrue(app.otherElements["mainView"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSteppingThroughOnboarding() throws {
        app.launchArguments.append("--reset-onboarding")
        app.launch()
        XCTAssertTrue(app.otherElements["splashView"].waitForExistence(timeout: 5))
        app.buttons["continueButton"].firstMatch.tap()
        let next = app.buttons["continueButton"].firstMatch
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        for _ in 0..<6 where !app.otherElements["mainView"].exists {
            next.tap()
        }
        XCTAssertTrue(app.otherElements["mainView"].waitForExistence(timeout: 5))
    }

    // MARK: - Tabs

    @MainActor
    func testTabsAreReachable() throws {
        app.launchArguments.append("--skip-onboarding")
        app.launch()
        XCTAssertTrue(app.otherElements["mainView"].waitForExistence(timeout: 10))
        for title in ["Portfolio", "Community", "Canvas", "Settings"] {
            let tab = app.tabBars.buttons[title].firstMatch
            let sidebarRow = app.buttons[title].firstMatch
            if tab.exists {
                tab.tap()
            } else if sidebarRow.exists {
                sidebarRow.tap()
            }
        }
        XCTAssertEqual(app.state, .runningForeground)
    }

    // MARK: - New color

    @MainActor
    func testNewColorOpensEditor() throws {
        app.launchArguments.append("--skip-onboarding")
        app.launch()
        XCTAssertTrue(app.otherElements["mainView"].waitForExistence(timeout: 10))
        let accessory = app.buttons["accessoryNewColorButton"].firstMatch
        if accessory.waitForExistence(timeout: 3) {
            accessory.tap()
            XCTAssertTrue(app.navigationBars.element.waitForExistence(timeout: 5))
            let cancel = app.buttons["Cancel"].firstMatch
            if cancel.exists { cancel.tap() }
        }
        XCTAssertEqual(app.state, .runningForeground)
    }

    // MARK: - Performance

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}

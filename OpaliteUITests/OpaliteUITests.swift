//
//  OpaliteUITests.swift
//  OpaliteUITests
//
//  Smoke tests over the shell: launch, the splash → onboarding → main flow, tab
//  navigation, and the Portfolio's "New Color" entry point. They use the accessibility
//  identifiers the feature modules publish (`splashView`, `continueButton`, `skipButton`,
//  `onboardingView`, `mainView`, `portfolio.createMenu`, `colorEditor.cancel`).
//

import XCTest

nonisolated final class OpaliteUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// Glass-styled buttons are not always exposed as `.button` elements, so look the
    /// identifier up across every element type; the splash button also animates in.
    @MainActor
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    private func tapContinue(file: StaticString = #filePath, line: UInt = #line) {
        let button = element("continueButton")
        XCTAssertTrue(button.waitForExistence(timeout: 5), "continueButton never appeared", file: file, line: line)
        button.tap()
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
        tapContinue()
        XCTAssertTrue(app.otherElements["onboardingView"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSkipFinishesOnboarding() throws {
        app.launchArguments.append("--reset-onboarding")
        app.launch()
        XCTAssertTrue(app.otherElements["splashView"].waitForExistence(timeout: 5))
        tapContinue()
        let skip = element("skipButton")
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        skip.tap()
        XCTAssertTrue(app.otherElements["mainView"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSteppingThroughOnboarding() throws {
        app.launchArguments.append("--reset-onboarding")
        app.launch()
        XCTAssertTrue(app.otherElements["splashView"].waitForExistence(timeout: 5))
        tapContinue()
        let next = element("continueButton")
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
        let createMenu = element("portfolio.createMenu")
        XCTAssertTrue(createMenu.waitForExistence(timeout: 5))
        createMenu.tap()
        let newColor = app.buttons["New Color"].firstMatch
        XCTAssertTrue(newColor.waitForExistence(timeout: 5))
        newColor.tap()
        let cancel = element("colorEditor.cancel")
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.tap()
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

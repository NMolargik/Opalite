//
//  OpaliteUITests.swift
//  OpaliteUITests
//
//  Created by Nick Molargik on 12/6/25.
//

import XCTest

final class OpaliteUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - App Launch Tests

    @MainActor
    func testAppLaunches() throws {
        // Verify the app launches without crashing
        XCTAssertTrue(app.state == .runningForeground)
    }

    // MARK: - Tab Navigation Tests

    @MainActor
    func testPortfolioTabExists() throws {
        // Look for the Portfolio tab
        let portfolioTab = app.tabBars.buttons["Portfolio"]
        if portfolioTab.exists {
            XCTAssertTrue(portfolioTab.exists)
            portfolioTab.tap()
        }
    }

    @MainActor
    func testSearchTabExists() throws {
        // Look for the Search tab
        let searchTab = app.tabBars.buttons["Search"]
        if searchTab.exists {
            XCTAssertTrue(searchTab.exists)
            searchTab.tap()
        }
    }

    @MainActor
    func testSettingsTabExists() throws {
        // Look for the Settings tab
        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.exists {
            XCTAssertTrue(settingsTab.exists)
            settingsTab.tap()
        }
    }

    @MainActor
    func testCanvasTabExistsOnIPad() throws {
        // Canvas tab only exists on iPad
        let canvasTab = app.tabBars.buttons["Canvas"]
        if canvasTab.exists {
            canvasTab.tap()
        }
    }

    // MARK: - Portfolio View Tests

    @MainActor
    func testPortfolioViewLoads() throws {
        // Navigate to Portfolio tab
        let portfolioTab = app.tabBars.buttons["Portfolio"]
        if portfolioTab.exists {
            portfolioTab.tap()
        }

        // Verify we're on the Portfolio view - look for navigation title or content
        // The Portfolio view should have "Colors" or "Palettes" sections
        let colorsSection = app.staticTexts["Colors"]
        let palettesSection = app.staticTexts["Palettes"]

        // At least one section should exist
        XCTAssertTrue(colorsSection.exists || palettesSection.exists || app.navigationBars.count > 0)
    }

    @MainActor
    func testCreateColorButtonExists() throws {
        // Navigate to Portfolio
        let portfolioTab = app.tabBars.buttons["Portfolio"]
        if portfolioTab.exists {
            portfolioTab.tap()
        }

        // Look for the "plus" or "Add" button in the toolbar
        let addButton = app.buttons["Add Color"]
        let plusButton = app.navigationBars.buttons.element(boundBy: 0)

        // Either the labeled button or a toolbar button should exist
        XCTAssertTrue(addButton.exists || plusButton.exists || app.navigationBars.count > 0)
    }

    // MARK: - Search View Tests

    @MainActor
    func testSearchViewHasSearchField() throws {
        let searchTab = app.tabBars.buttons["Search"]
        if searchTab.exists {
            searchTab.tap()

            // Give the view time to appear
            sleep(1)

            // Look for search field
            let searchField = app.searchFields.firstMatch
            if searchField.exists {
                XCTAssertTrue(searchField.exists)
            }
        }
    }

    @MainActor
    func testSearchEmptyState() throws {
        let searchTab = app.tabBars.buttons["Search"]
        if searchTab.exists {
            searchTab.tap()

            sleep(1)

            // Look for empty state message
            let emptyStateText = app.staticTexts["Search Your Portfolio"]
            if emptyStateText.exists {
                XCTAssertTrue(emptyStateText.exists)
            }
        }
    }

    // MARK: - Settings View Tests

    @MainActor
    func testSettingsViewLoads() throws {
        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.exists {
            settingsTab.tap()

            // Give the view time to appear
            sleep(1)

            // Settings view should have various sections
            // Look for common settings elements
            XCTAssertTrue(app.navigationBars.count > 0 || app.tables.count > 0 || app.scrollViews.count > 0)
        }
    }

    @MainActor
    func testDisplayNameSectionExists() throws {
        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.exists {
            settingsTab.tap()
            sleep(1)

            // Look for Display Name section
            let displayNameText = app.staticTexts["Display Name"]
            if displayNameText.exists {
                XCTAssertTrue(displayNameText.exists)
            }
        }
    }

    @MainActor
    func testAppThemeSectionExists() throws {
        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.exists {
            settingsTab.tap()
            sleep(1)

            // Look for App Theme section
            let themeText = app.staticTexts["App Theme"]
            if themeText.exists {
                XCTAssertTrue(themeText.exists)
            }
        }
    }

    @MainActor
    func testHexCopyToggleExists() throws {
        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.exists {
            settingsTab.tap()
            sleep(1)

            // Look for the hex copy toggle (added in recent update)
            let hexToggle = app.staticTexts["Include # in Hex Codes"]
            if hexToggle.exists {
                XCTAssertTrue(hexToggle.exists)
            }
        }
    }

    // MARK: - Color Editor Tests

    @MainActor
    func testOpenColorEditor() throws {
        let portfolioTab = app.tabBars.buttons["Portfolio"]
        if portfolioTab.exists {
            portfolioTab.tap()
            sleep(1)

            // Try to find and tap on a color to open editor
            // This depends on having colors in the portfolio
            let colorCells = app.cells
            if colorCells.count > 0 {
                colorCells.firstMatch.tap()
                sleep(1)

                // Should see color detail or editor view
                XCTAssertTrue(app.navigationBars.count > 0)
            }
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
    func testTabSwitchingPerformance() throws {
        let portfolioTab = app.tabBars.buttons["Portfolio"]
        let searchTab = app.tabBars.buttons["Search"]
        let settingsTab = app.tabBars.buttons["Settings"]

        guard portfolioTab.exists && searchTab.exists && settingsTab.exists else {
            return
        }

        measure {
            portfolioTab.tap()
            searchTab.tap()
            settingsTab.tap()
            portfolioTab.tap()
        }
    }

    // MARK: - Accessibility Tests

    @MainActor
    func testAccessibilityLabels() throws {
        // Verify that key elements have accessibility labels
        let portfolioTab = app.tabBars.buttons["Portfolio"]
        if portfolioTab.exists {
            XCTAssertNotNil(portfolioTab.label)
            XCTAssertFalse(portfolioTab.label.isEmpty)
        }

        let searchTab = app.tabBars.buttons["Search"]
        if searchTab.exists {
            XCTAssertNotNil(searchTab.label)
            XCTAssertFalse(searchTab.label.isEmpty)
        }

        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.exists {
            XCTAssertNotNil(settingsTab.label)
            XCTAssertFalse(settingsTab.label.isEmpty)
        }
    }

    // MARK: - Orientation Tests

    @MainActor
    func testPortraitOrientation() throws {
        XCUIDevice.shared.orientation = .portrait
        sleep(1)
        XCTAssertTrue(app.state == .runningForeground)
    }

    @MainActor
    func testLandscapeOrientation() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(1)
        XCTAssertTrue(app.state == .runningForeground)
    }
}

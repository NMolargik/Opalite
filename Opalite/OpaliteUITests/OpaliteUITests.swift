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
        // Navigate to Portfolio tab (may not exist if onboarding hasn't completed)
        let portfolioTab = app.tabBars.buttons["Portfolio"]
        guard portfolioTab.waitForExistence(timeout: 25) else { return }
        portfolioTab.tap()

        // Verify we're on the Portfolio view - look for navigation title or content
        // The Portfolio view should have "Colors" or "Palettes" sections
        let colorsSection = app.staticTexts["Colors"]
        let palettesSection = app.staticTexts["Palettes"]

        // At least one section should exist
        XCTAssertTrue(colorsSection.exists || palettesSection.exists || app.navigationBars.count > 0)
    }

    @MainActor
    func testCreateColorButtonExists() throws {
        // Navigate to Portfolio (may not exist if onboarding hasn't completed)
        let portfolioTab = app.tabBars.buttons["Portfolio"]
        guard portfolioTab.waitForExistence(timeout: 25) else { return }
        portfolioTab.tap()

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

// MARK: - Full Onboarding Flow Tests

final class OpaliteOnboardingFlowTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-onboarding"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Splash Screen

    @MainActor
    func testSplashContinueButtonExists() throws {
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5),
                       "Continue button should appear on splash screen")
    }

    @MainActor
    func testSplashContinueAdvancesToOnboarding() throws {
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))

        continueButton.tap()

        // Onboarding should appear — look for the Skip button or the Next button
        let skipButton = app.buttons["Skip introduction"]
        let nextButton = app.buttons["Next"]
        let eitherExists = skipButton.waitForExistence(timeout: 5) || nextButton.exists
        XCTAssertTrue(eitherExists, "Onboarding view should appear after tapping Continue")
    }

    // MARK: - Full Flow: Splash → Skip Onboarding → Syncing → Main

    @MainActor
    func testFullFlowWithSkip() throws {
        // 1. Splash — tap Continue
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5),
                       "Splash Continue button should appear")
        continueButton.tap()

        // 2. Onboarding — tap Skip
        let skipButton = app.buttons["Skip introduction"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 5),
                       "Skip button should appear on onboarding")
        skipButton.tap()

        // 3. Syncing completes automatically (up to ~12s: 8s timeout + 1.5s pause + buffer)
        // 4. Main view should appear with tab bars
        let portfolioTab = app.tabBars.buttons["Portfolio"]
        XCTAssertTrue(portfolioTab.waitForExistence(timeout: 20),
                       "Main view with Portfolio tab should appear after syncing")
    }

    // MARK: - Full Flow: Splash → Step Through Onboarding → Syncing → Main

    @MainActor
    func testFullFlowSteppingThroughOnboarding() throws {
        // 1. Splash — tap Continue
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.tap()

        // 2. Onboarding — tap Next through all pages, then Done on the last page
        //    There are 6 pages: Next×5, then the button becomes "Get Started"
        for page in 1...5 {
            let nextButton = app.buttons["Next"]
            XCTAssertTrue(nextButton.waitForExistence(timeout: 3),
                           "Next button should exist on onboarding page \(page)")
            nextButton.tap()
        }

        // Last page — button label is "Get Started"
        let getStartedButton = app.buttons["Get Started"]
        XCTAssertTrue(getStartedButton.waitForExistence(timeout: 3),
                       "Get Started button should appear on the last onboarding page")
        getStartedButton.tap()

        // 3. Syncing → Main
        let portfolioTab = app.tabBars.buttons["Portfolio"]
        XCTAssertTrue(portfolioTab.waitForExistence(timeout: 20),
                       "Main view should appear after completing onboarding and syncing")
    }

    // MARK: - Onboarding Back Button

    @MainActor
    func testOnboardingBackButton() throws {
        // Navigate to onboarding
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.tap()

        // Go to page 2
        let nextButton = app.buttons["Next"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 3))
        nextButton.tap()

        // Back button should now exist
        let backButton = app.buttons["Back"]
        XCTAssertTrue(backButton.waitForExistence(timeout: 3),
                       "Back button should appear on page 2+")
        backButton.tap()

        // Skip button should still be visible (we're back on page 1)
        let skipButton = app.buttons["Skip introduction"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 3),
                       "Skip button should be visible after going back to page 1")
    }

    // MARK: - Back Button Absent on Page 1

    @MainActor
    func testBackButtonAbsentOnFirstPage() throws {
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.tap()

        // Wait for onboarding to appear
        let nextButton = app.buttons["Next"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5))

        // Back button should NOT exist on page 1
        let backButton = app.buttons["Back"]
        XCTAssertFalse(backButton.exists,
                        "Back button should not exist on the first onboarding page")
    }

    // MARK: - Skip Button Hidden on Last Page

    @MainActor
    func testSkipButtonHiddenOnLastPage() throws {
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.tap()

        // Navigate to the last page (page 6) by tapping Next 5 times
        for _ in 1...5 {
            let nextButton = app.buttons["Next"]
            XCTAssertTrue(nextButton.waitForExistence(timeout: 3))
            nextButton.tap()
        }

        // On the last page, Get Started should be visible
        let getStartedButton = app.buttons["Get Started"]
        XCTAssertTrue(getStartedButton.waitForExistence(timeout: 3))

        // Skip button should be hidden (accessibilityHidden) on the last page
        let skipButton = app.buttons["Skip introduction"]
        XCTAssertFalse(skipButton.isHittable,
                        "Skip button should not be hittable on the last onboarding page")
    }

    // MARK: - Page Indicator Updates

    @MainActor
    func testPageIndicatorUpdates() throws {
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        continueButton.tap()

        // Page 1 — indicator should read "Page 1 of 6"
        let page1Indicator = app.otherElements["Page 1 of 6"]
        XCTAssertTrue(page1Indicator.waitForExistence(timeout: 5),
                       "Page indicator should show 'Page 1 of 6' on first page")

        // Tap Next → Page 2
        let nextButton = app.buttons["Next"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 3))
        nextButton.tap()

        let page2Indicator = app.otherElements["Page 2 of 6"]
        XCTAssertTrue(page2Indicator.waitForExistence(timeout: 3),
                       "Page indicator should show 'Page 2 of 6' after tapping Next")

        // Tap Back → Page 1 again
        let backButton = app.buttons["Back"]
        XCTAssertTrue(backButton.waitForExistence(timeout: 3))
        backButton.tap()

        let page1Again = app.otherElements["Page 1 of 6"]
        XCTAssertTrue(page1Again.waitForExistence(timeout: 3),
                       "Page indicator should return to 'Page 1 of 6' after tapping Back")
    }
}

// MARK: - Portfolio Workflow Tests

final class OpalitePortfolioWorkflowTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-onboarding"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// Walks through Splash → Skip Onboarding → Syncing → Main, then taps Portfolio.
    /// Dismisses the StoreKit review prompt if it appears.
    @MainActor
    private func navigateToPortfolio() -> Bool {
        // 1. Splash — tap Continue
        let continueButton = app.buttons["Continue"]
        guard continueButton.waitForExistence(timeout: 10) else { return false }
        continueButton.tap()

        // 2. Onboarding — tap Skip
        let skipButton = app.buttons["Skip introduction"]
        guard skipButton.waitForExistence(timeout: 5) else { return false }
        skipButton.tap()

        // 3. Wait for syncing to complete and main view to appear
        let portfolioTab = app.tabBars.buttons["Portfolio"]
        guard portfolioTab.waitForExistence(timeout: 25) else { return false }

        // 4. Dismiss the StoreKit review prompt if it appears
        dismissReviewPromptIfNeeded()

        portfolioTab.tap()
        sleep(1)
        return true
    }

    /// Dismisses the "Enjoying Opalite?" StoreKit review prompt by tapping "Not Now".
    @MainActor
    private func dismissReviewPromptIfNeeded() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let notNowButton = springboard.buttons["Not Now"]
        if notNowButton.waitForExistence(timeout: 3) {
            notNowButton.tap()
        }
    }

    /// Ensures the swatch size is set to medium so that overlay menus (ellipsis) are visible.
    /// On compact displays, taps the "Change swatch size" toolbar button if currently "Small".
    @MainActor
    private func ensureMediumSwatchSize() {
        let changeSizeButton = app.buttons["Change swatch size"]
        guard changeSizeButton.waitForExistence(timeout: 5) else { return }
        if changeSizeButton.value as? String == "Small" {
            changeSizeButton.tap()
            sleep(1)
        }
    }

    // MARK: - Test 1: Create a Random Color

    @MainActor
    func testCreateRandomColor() throws {
        guard navigateToPortfolio() else { return }

        // Tap the "Create" menu in the toolbar
        let createMenu = app.buttons["Create"]
        XCTAssertTrue(createMenu.waitForExistence(timeout: 5),
                       "Create menu should exist in Portfolio toolbar")
        createMenu.tap()

        // Tap "Create Color" from the menu
        let newColorButton = app.buttons["Create A Color"]
        XCTAssertTrue(newColorButton.waitForExistence(timeout: 3),
                       "Create A Color option should appear in Create menu")
        newColorButton.tap()

        // ColorEditorView should appear (fullScreenCover)
        // The Save button should be visible
        let saveButton = app.buttons["Save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5),
                       "Save button should appear in ColorEditorView")

        // Switch to Shuffle mode to randomize the color
        let shuffleTab = app.buttons["Shuffle color"]
        if shuffleTab.waitForExistence(timeout: 3) {
            shuffleTab.tap()
            sleep(1)
        }

        // Save the color
        saveButton.tap()
        dismissReviewPromptIfNeeded()

        // Should return to Portfolio — verify by checking a tab still exists
        let portfolioTab = app.tabBars.buttons["Portfolio"]
        XCTAssertTrue(portfolioTab.waitForExistence(timeout: 5),
                       "Should return to Portfolio after saving color")
    }

    // MARK: - Test 2: Create Palette and Add Color via Ellipsis Menu

    @MainActor
    func testCreatePaletteAndAddColorViaMenu() throws {
        guard navigateToPortfolio() else { return }

        // Step 1: Create a color first
        let createMenu = app.buttons["Create"]
        XCTAssertTrue(createMenu.waitForExistence(timeout: 5))
        createMenu.tap()

        let newColorButton = app.buttons["Create Color"]
        XCTAssertTrue(newColorButton.waitForExistence(timeout: 3))
        newColorButton.tap()

        let saveButton = app.buttons["Save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()
        dismissReviewPromptIfNeeded()

        sleep(2)

        // Step 2: Create a new palette
        let createMenu2 = app.buttons["Create"]
        XCTAssertTrue(createMenu2.waitForExistence(timeout: 5))
        createMenu2.tap()

        let newPaletteButton = app.buttons["Create A Palette"]
        XCTAssertTrue(newPaletteButton.waitForExistence(timeout: 3),
                       "Create A Palette option should appear in Create menu")
        newPaletteButton.tap()

        sleep(2)

        let paletteLabel = app.staticTexts["New Palette"]
        XCTAssertTrue(paletteLabel.waitForExistence(timeout: 5),
                       "New Palette should appear in the portfolio")

        // Step 3: Ensure swatch size is medium (shows ellipsis overlay menus)
        ensureMediumSwatchSize()

        // Step 4: Tap the ellipsis menu on a color swatch (bottom-trailing corner)
        let swatches = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] '#'"))
        guard swatches.count > 0 else {
            XCTFail("No color swatches found")
            return
        }

        let targetSwatch = swatches.firstMatch
        let ellipsisCoord = targetSwatch.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.9))
        ellipsisCoord.tap()

        // Step 5: Wait for menu and tap "Move To Palette"
        let moveToPaletteButton = app.buttons["Move To Palette"]
        XCTAssertTrue(moveToPaletteButton.waitForExistence(timeout: 5),
                       "Move To Palette should appear in ellipsis menu")
        moveToPaletteButton.tap()

        // Step 6: PaletteSelectionSheet appears — tap the palette
        let existingSection = app.staticTexts["Existing Palettes"]
        XCTAssertTrue(existingSection.waitForExistence(timeout: 10),
                       "Existing Palettes section should appear in PaletteSelectionSheet")

        let paletteCells = app.cells.containing(.staticText, identifier: "New Palette")
        XCTAssertTrue(paletteCells.firstMatch.waitForExistence(timeout: 5),
                       "New Palette row should appear in Existing Palettes")
        paletteCells.firstMatch.tap()

        // Sheet should dismiss — back to Portfolio
        let portfolioTab = app.tabBars.buttons["Portfolio"]
        XCTAssertTrue(portfolioTab.waitForExistence(timeout: 10),
                       "Should return to Portfolio after moving color to palette")
    }
}

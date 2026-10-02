//
//  OpaliteIntents.swift
//  Opalite
//
//  Custom App Intents exposing the portfolio to Siri, Shortcuts, Spotlight, and the
//  system. Data-mutating intents run in-process through the session's use-cases;
//  navigation intents hand a deep link to the app via the App Group.
//

import AppIntents
import Foundation
import OpaliteComposition
import OpaliteCore
import OpaliteFeatureShared

// MARK: - Navigation target

enum OpaliteScreen: String, AppEnum {
    case portfolio, community, search, canvases, settings, onyx

    nonisolated static var typeDisplayRepresentation: TypeDisplayRepresentation { "Opalite Screen" }

    nonisolated static var caseDisplayRepresentations: [OpaliteScreen: DisplayRepresentation] {
        [.portfolio: "Portfolio", .community: "Community", .search: "Search", .canvases: "Canvases", .settings: "Settings", .onyx: "Onyx"]
    }

    var deepLink: DeepLink {
        switch self {
        case .portfolio: .portfolio
        case .community: .community
        case .search: .search
        case .canvases: .canvases
        case .settings: .settings
        case .onyx: .onyx
        }
    }
}

struct OpenOpaliteIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Opalite"
    static let description = IntentDescription("Opens Opalite to a specific screen.")
    static let openAppWhenRun = true

    @Parameter(title: "Screen", default: .portfolio)
    var screen: OpaliteScreen

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$screen)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        screen.deepLink.storePending(in: AppGroup.defaults)
        return .result()
    }
}

// MARK: - Show a color / palette

struct ShowColorIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Color"
    static let description = IntentDescription("Opens a specific color in Opalite.")
    static let openAppWhenRun = true

    @Parameter(title: "Color")
    var color: ColorEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Show \(\.$color)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        DeepLink.color(color.id).storePending(in: AppGroup.defaults)
        return .result()
    }
}

struct ShowPaletteIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Palette"
    static let description = IntentDescription("Opens a specific palette in Opalite.")
    static let openAppWhenRun = true

    @Parameter(title: "Palette")
    var palette: PaletteEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Show \(\.$palette)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        DeepLink.palette(palette.id).storePending(in: AppGroup.defaults)
        return .result()
    }
}

// MARK: - Create a color (background)

struct CreateColorIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Color"
    static let description = IntentDescription("Saves a color to your Portfolio from a hex code, without opening the app.")

    @Parameter(title: "Hex Code", description: "Like #FF5733 or 3380CC")
    var hex: String

    @Parameter(title: "Name")
    var name: String?

    @Parameter(title: "Palette")
    var palette: PaletteEntity?

    @Dependency private var session: SessionController

    static var parameterSummary: some ParameterSummary {
        Summary("Create \(\.$hex) named \(\.$name)") {
            \.$palette
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<ColorEntity> & ProvidesDialog {
        guard let rgba = RGBA(hex: hex) else {
            throw $hex.needsValueError("That doesn't look like a hex code. Try something like #FF5733.")
        }
        let target = try palette.flatMap { try session.findPalette(withID: $0.id) }
        let color = try session.createColor(rgba, name: name?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty, notes: nil, palette: target, authorship: session.portfolio.authorship)
        session.portfolio.refresh()
        let entity = ColorEntity(color)
        return .result(value: entity, dialog: "Saved \(entity.name ?? entity.hexString) to your Portfolio.")
    }
}

// MARK: - Create a palette (opens the app if the limit is hit)

struct CreatePaletteIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Palette"
    static let description = IntentDescription("Creates an empty palette in your Portfolio.")

    @Parameter(title: "Name")
    var name: String

    @Dependency private var session: SessionController

    static var parameterSummary: some ParameterSummary {
        Summary("Create a palette named \(\.$name)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<PaletteEntity> & ProvidesDialog {
        do {
            let palette = try session.createPalette(name: name, notes: nil, tags: [], colors: [], authorship: session.portfolio.authorship)
            session.portfolio.refresh()
            return .result(value: PaletteEntity(palette), dialog: "Created \(palette.name).")
        } catch PaletteCreationError.limitReached {
            DeepLink.onyx.storePending(in: AppGroup.defaults)
            throw OpaliteError.paletteLimitReached
        }
    }
}

// MARK: - Copy / read a color's hex

struct CopyColorHexIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Color Hex"
    static let description = IntentDescription("Returns a color's hex code and copies it to the clipboard.")

    @Parameter(title: "Color")
    var color: ColorEntity

    @Dependency private var session: SessionController

    static var parameterSummary: some ParameterSummary {
        Summary("Get the hex code of \(\.$color)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let hex = session.hexCopy.formatted(color.hexString)
        session.hexCopy.copy(hex: color.hexString)
        return .result(value: hex, dialog: "\(color.name ?? color.hexString) is \(hex). Copied.")
    }
}

// MARK: - A random color

struct RandomColorIntent: AppIntent {
    static let title: LocalizedStringResource = "Random Color"
    static let description = IntentDescription("Picks a random color from your Portfolio.")

    @Dependency private var session: SessionController

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<ColorEntity?> & ProvidesDialog {
        guard let color = try session.loadColors().randomElement() else {
            return .result(value: nil, dialog: "You haven't saved any colors yet.")
        }
        let entity = ColorEntity(color)
        return .result(value: entity, dialog: "How about \(entity.name ?? entity.hexString)? It's \(entity.hexString).")
    }
}

// MARK: - A palette's colors

struct PaletteColorsIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Palette Colors"
    static let description = IntentDescription("Returns the colors in a palette.")

    @Parameter(title: "Palette")
    var palette: PaletteEntity

    @Dependency private var session: SessionController

    static var parameterSummary: some ParameterSummary {
        Summary("Get the colors in \(\.$palette)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[ColorEntity]> & ProvidesDialog {
        guard let palette = try session.findPalette(withID: palette.id) else {
            throw OpaliteIntentError.notFound
        }
        let colors = palette.sortedColors.map(ColorEntity.init)
        let names = colors.map { $0.name ?? $0.hexString }.joined(separator: ", ")
        return .result(value: colors, dialog: colors.isEmpty ? "\(palette.name) is empty." : "\(palette.name) has \(names).")
    }
}

// MARK: - Portfolio summary

struct PortfolioSummaryIntent: AppIntent {
    static let title: LocalizedStringResource = "Portfolio Summary"
    static let description = IntentDescription("Tells you how many colors and palettes you've saved.")

    @Dependency private var session: SessionController

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let colors = try session.loadColors().count
        let palettes = try session.loadPalettes().filter { !$0.isArchived }.count
        return .result(value: colors, dialog: "You have \(colors) colors across \(palettes) palettes.")
    }
}

// MARK: - Errors

enum OpaliteIntentError: Error, CustomLocalizedStringResourceConvertible {
    case notFound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notFound: "That item no longer exists."
        }
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}

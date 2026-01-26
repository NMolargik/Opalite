<img src="Icons/AppIcon-iOS-Default-1024x1024@1x.png" alt="Opalite" width="128" height="128">

# Opalite

A native color management and digital design app for Apple platforms.

## Overview

Opalite helps designers, artists, and developers manage colors and create digital artwork. It combines precise color picking with palette organization and a PencilKit-based drawing canvas. Built with SwiftUI and SwiftData, it features seamless iCloud sync across iPhone, iPad, Mac, Apple TV, and Vision Pro.

## Features

### Color Management
- **Color Picker**: Five picker modes - grid, spectrum, sliders, hex codes, and image sampling
- **Palette Organization**: Create and manage color collections with drag-to-reorder
- **Color Details**: View sRGB components, hex codes, and metadata
- **Quick Access**: SwatchBoard for rapid color selection

### Drawing Canvas
- **PencilKit Integration**: Full Apple Pencil support with pressure sensitivity
- **Shape Tools**: Built-in shape drawing capabilities
- **Canvas Files**: Save and organize multiple drawings
- **Color Integration**: Use palette colors directly in your artwork

### Platform Integration
- **iCloud Sync**: Seamless sync via CloudKit across all devices
- **Universal App**: iPhone, iPad, Mac (Catalyst), Apple TV, and Vision Pro
- **Adaptive Layout**: Size-class responsive design for all screen sizes

### Export & Sharing
- Share colors and palettes via share sheet
- Export drawings from canvas

## Requirements - One Of

- iOS 18.4+
- iPadOS 18.4+
- macOS (Catalyst)
- visionOS
- tvOS
- Xcode 15.0+
- Apple Developer account (for CloudKit capabilities)

## Setup

1. Clone the repository
2. Open `Opalite/Opalite.xcodeproj` in Xcode
3. Configure signing with your Apple Developer account
4. Update bundle identifiers and iCloud container identifiers
5. Build and run

### Required Capabilities

Enable these in your Xcode project:
- iCloud (CloudKit with private database)
- App Groups

### Dependencies

- **DeviceKit** (SPM) - the only external dependency

## Architecture

### App Lifecycle

The app progresses through stages managed by `ContentView`:

```
.splash → .onboarding → .main
```

### Manager Pattern

Business logic lives in `@Observable` manager classes:

| Manager | Responsibility |
|---------|---------------|
| `ColorManager` | Color/palette CRUD, caching, relationships |
| `CanvasManager` | Canvas file operations and persistence |

### Data Layer

- **SwiftData** with iCloud CloudKit sync
- **App Groups** for cross-target data sharing
- External data files for canvas storage

### Data Models

| Model | Description |
|-------|-------------|
| `OpaliteColor` | Single color with sRGB components and metadata |
| `OpalitePalette` | Collection of colors with bi-directional relationships |
| `CanvasFile` | PencilKit drawing with external data storage |

### Key Patterns

- **MVVM**: ViewModels as nested classes (e.g., `ColorEditorView.ViewModel`)
- **Dependency Injection**: Managers injected via SwiftUI `@Environment`
- **Adaptive Layout**: Size-class responsive with device-specific tabs
- **Platform Guards**: `#if` guards for visionOS/macOS-specific code

## Project Structure

```
Opalite/Opalite/
├── OpaliteApp.swift            # App entry point
├── ContentView.swift           # App stage state machine
├── Models/                     # SwiftData @Model classes
│   ├── OpaliteColor.swift
│   ├── OpalitePalette.swift
│   └── CanvasFile.swift
├── Managers/                   # Observable data managers
│   ├── ColorManager.swift
│   └── CanvasManager.swift
├── Views/
│   ├── Main/
│   │   ├── Portfolio/          # Color/palette management
│   │   ├── Color Editing/      # ColorEditorView + 5 picker modes
│   │   ├── Canvas/             # PencilKit drawing
│   │   ├── SwatchBoard/        # Quick access color grid
│   │   └── Settings/           # App preferences
│   ├── Onboarding/             # First-run setup
│   └── Splash/                 # Launch screen
├── Enumerations/               # Tabs, Routes, AppStage
├── Extensions/                 # View modifiers, Color+RGBA
└── Sharing/                    # Share sheet functionality

OpaliteTV/                      # tvOS target
```

## Privacy

Opalite is designed with privacy in mind:
- All data stored in your private iCloud container
- No analytics or tracking
- No color or artwork data shared with third parties

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

Molargik Software LLC

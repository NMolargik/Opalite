//
//  OpaliteStore.swift
//  OpaliteData
//
//  Builds the SwiftData container, degrading gracefully when CloudKit is unavailable:
//  CloudKit-synced → local-only → in-memory (the old app fatal-errored). No fatalError
//  short of a machine that can't allocate memory.
//

import Foundation
import SwiftData
import OpaliteCore
import os

public enum OpaliteStore {
    /// The model types persisted by the app (one schema everywhere so CloudKit agrees).
    public static let schema = Schema([
        OpaliteColor.self,
        OpalitePalette.self,
        CanvasFile.self,
    ])

    public static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        if inMemory {
            do {
                let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                return try ModelContainer(for: schema, configurations: memory)
            } catch {
                fatalError("Failed to create an in-memory ModelContainer: \(error)")
            }
        }

        do {
            let cloud = ModelConfiguration(schema: schema, cloudKitDatabase: .private(AppGroup.cloudKitContainerID))
            return try ModelContainer(for: schema, configurations: cloud)
        } catch {
            Log.app.error("CloudKit container unavailable, falling back to local store: \(error.localizedDescription)")
        }

        do {
            let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: local)
        } catch {
            Log.app.fault("Local store unavailable, falling back to in-memory: \(error.localizedDescription)")
        }

        do {
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: memory)
        } catch {
            fatalError("Failed to create even an in-memory ModelContainer: \(error)")
        }
    }

    /// A container backed by a unique on-disk temp store: the shape tests and previews
    /// need (parallel in-memory containers share a /dev/null SQLite identity).
    public static func makeTemporaryContainer() throws -> ModelContainer {
        let url = URL.temporaryDirectory.appending(path: "opalite-\(UUID().uuidString).store")
        let config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: config)
    }
}

// MARK: - Shared save helper

extension ModelContext {
    /// Saves pending changes, mapping failures to the typed persistence error.
    func saveTyped() throws(PersistenceError) {
        guard hasChanges else { return }
        do {
            try save()
        } catch {
            throw .saveFailed(error.localizedDescription)
        }
    }

    func fetchTyped<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) throws(PersistenceError) -> [T] {
        do {
            return try fetch(descriptor)
        } catch {
            throw .fetchFailed(error.localizedDescription)
        }
    }
}

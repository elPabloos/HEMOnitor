//
//  FileManagerPersistenceStore.swift
//  HEMOnitor
//

import Foundation

/// On-disk persistence, as JSON, under the Application Support directory.
/// Writes are atomic (`Data.write(options: .atomic)`, which writes to a temp
/// file first and then renames) so no corrupt file is left behind if the app is
/// killed mid-write. If the file is missing or can't be decoded (first launch,
/// or an old/corrupt file), it silently falls back to `AppState()` (the defaults).
final class FileManagerPersistenceStore: PersistenceStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileName: String = "app_state.json") {
        let baseDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
        self.fileURL = baseDir.appendingPathComponent(fileName)

        // millisecondsSince1970, not .iso8601: the default ISO8601 formatter drops
        // sub-second precision, so a `Date()` with fractional seconds doesn't
        // round-trip exactly through save/load.
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        self.decoder = decoder
    }

    func load() -> AppState {
        guard let data = try? Data(contentsOf: fileURL),
              let state = try? decoder.decode(AppState.self, from: data)
        else {
            return AppState()
        }
        return state
    }

    func save(_ state: AppState) {
        guard let data = try? encoder.encode(state) else {
            assertionFailure("Could not encode the app state for saving")
            return
        }
        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            assertionFailure("Could not save the app state: \(error)")
        }
    }
}

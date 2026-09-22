//
//  FileManagerPersistenceStore.swift
//  HEMOnitor
//

import Foundation

/// Persistență pe disc, ca JSON, sub directorul Application Support.
/// Scrierea e atomică (`Data.write(options: .atomic)`, care scrie mai întâi
/// într-un fișier temporar și apoi redenumește) ca să nu rămână un fișier
/// corupt dacă aplicația e omorâtă în timpul scrierii. Dacă fișierul lipsește
/// sau nu poate fi decodat (prima rulare, sau un fișier vechi/corupt), se
/// întoarce silențios la `AppState()` (valorile implicite).
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
            assertionFailure("Nu am putut coda starea aplicației pentru salvare")
            return
        }
        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            assertionFailure("Nu am putut salva starea aplicației: \(error)")
        }
    }
}

//
//  ExportStaging.swift
//  PassportProof
//
//  Share files have one private directory and an explicit lifetime. Startup
//  cleanup removes abandoned files from earlier processes, never active shares.
//

import Foundation

@MainActor
enum ExportStaging {
    enum StagingError: Error {
        case invalidExtension
        case unsafeDirectory
    }

    private static let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("PassportProofExports", isDirectory: true)
    private static var activeFiles: Set<URL> = []

    /// Creates a protected file and retains its lifetime until remove(_:) is
    /// called. A name can never introduce a path component into this directory.
    static func stage(data: Data, name: String, fileExtension: String) throws -> URL {
        let fileExtension = fileExtension.lowercased()
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789")
        guard !fileExtension.isEmpty, fileExtension.count <= 10,
              fileExtension.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            throw StagingError.invalidExtension
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard isSafeDirectory else { throw StagingError.unsafeDirectory }

        let nameCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        let sanitized = String(name.unicodeScalars.map { nameCharacters.contains($0) ? Character(String($0)) : "-" }.prefix(64))
        let safeName = sanitized.isEmpty ? "photo" : sanitized
        let url = directory.appendingPathComponent("\(safeName)-\(UUID().uuidString)")
            .appendingPathExtension(fileExtension).standardizedFileURL
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        activeFiles.insert(url)
        return url
    }

    /// Refuses URLs outside the dedicated directory. Repeated completion and
    /// dismissal callbacks are safe, including after an activity was cancelled.
    @discardableResult
    static func remove(_ url: URL) -> Bool {
        let url = url.standardizedFileURL
        guard owns(url), isSafeDirectory else { return false }
        activeFiles.remove(url)
        guard FileManager.default.fileExists(atPath: url.path) else { return true }
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
              values.isRegularFile == true, values.isSymbolicLink != true else { return false }
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            return false
        }
    }

    /// Call once at launch. In-process active files are excluded even if this
    /// method is called again while a share extension is reading a staged file.
    @discardableResult
    static func cleanupAbandonedFiles() -> Int {
        guard isSafeDirectory,
              let files = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey]
              ) else { return 0 }
        var removed = 0
        for file in files {
            let file = file.standardizedFileURL
            guard owns(file), !activeFiles.contains(file),
                  let values = try? file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
                  values.isRegularFile == true, values.isSymbolicLink != true else { continue }
            if (try? FileManager.default.removeItem(at: file)) != nil { removed += 1 }
        }
        return removed
    }

    private static func owns(_ url: URL) -> Bool {
        url.isFileURL && url.deletingLastPathComponent() == directory.standardizedFileURL
    }

    private static var isSafeDirectory: Bool {
        guard let values = try? directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else { return false }
        return values.isDirectory == true && values.isSymbolicLink != true
    }
}

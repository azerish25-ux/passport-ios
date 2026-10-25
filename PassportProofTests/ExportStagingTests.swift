import XCTest
@testable import PassportProof

final class ExportStagingTests: XCTestCase {
    @MainActor
    func testStageSanitizesPathsAndPreservesTheExactBytes() throws {
        let data = Data([0, 1, 2, 255])
        let first = try ExportStaging.stage(data: data, name: "../../passport/photo", fileExtension: "jpg")
        defer { ExportStaging.remove(first) }
        let second = try ExportStaging.stage(data: data, name: "../../passport/photo", fileExtension: "jpg")
        defer { ExportStaging.remove(second) }

        XCTAssertEqual(first.deletingLastPathComponent().lastPathComponent, "PassportProofExports")
        XCTAssertFalse(first.lastPathComponent.contains("/"))
        XCTAssertEqual(first.pathExtension, "jpg")
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(try Data(contentsOf: first), data)
        XCTAssertThrowsError(try ExportStaging.stage(data: data, name: "photo", fileExtension: "../jpg"))
    }

    @MainActor
    func testCleanupRemovesAbandonedFilesButProtectsActiveShareAndOtherStorage() throws {
        let active = try ExportStaging.stage(data: Data([7]), name: "active", fileExtension: "pdf")
        defer { ExportStaging.remove(active) }
        let abandoned = active.deletingLastPathComponent().appendingPathComponent("abandoned-\(UUID().uuidString).pdf")
        let unrelated = FileManager.default.temporaryDirectory.appendingPathComponent("unrelated-\(UUID().uuidString).pdf")
        try Data([8]).write(to: abandoned)
        try Data([9]).write(to: unrelated)
        defer {
            try? FileManager.default.removeItem(at: abandoned)
            try? FileManager.default.removeItem(at: unrelated)
        }

        XCTAssertGreaterThanOrEqual(ExportStaging.cleanupAbandonedFiles(), 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: abandoned.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: active.path))
        XCTAssertFalse(ExportStaging.remove(unrelated))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelated.path))
        XCTAssertTrue(ExportStaging.remove(active))
        XCTAssertFalse(FileManager.default.fileExists(atPath: active.path))
        XCTAssertTrue(ExportStaging.remove(active), "Duplicate completion/dismissal cleanup must be harmless")
    }
}

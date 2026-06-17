import XCTest

final class ArchitectureTests: XCTestCase {
    private let forbiddenTokens = [
        "RankedResult",
        "BM25Index",
        "EmbeddingIndex",
        "QueryIntent",
        "HybridRanker",
    ]

    func testUIFilesDoNotImportDomainTypes() throws {
        let uiDir = repoRoot().appendingPathComponent("MQUPApp/UI")
        let files = try FileManager.default.contentsOfDirectory(at: uiDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }

        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            for token in forbiddenTokens {
                XCTAssertFalse(
                    source.contains("import \(token)"),
                    "\(file.lastPathComponent) must not import \(token)"
                )
            }
        }
    }

    private func repoRoot() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 {
            url.deleteLastPathComponent()
            if FileManager.default.fileExists(atPath: url.appendingPathComponent("MQUPApp/UI").path) {
                return url
            }
        }
        fatalError("Could not locate repo root")
    }
}

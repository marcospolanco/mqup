import MQUPEngine
import XCTest

final class ResumeBulletGeneratorTests: XCTestCase {
    func testRenderUsesHybridLatencyNotBM25() {
        let text = ResumeBulletGenerator.render(
            ResumeBulletGenerator.Input(
                tunedAlpha: 0.40,
                nDCGDelta: 0.67474893138520387,
                recallAt10: 0.998,
                hybridP95LatencyMs: 10.071375
            )
        )
        XCTAssertTrue(text.contains("deterministic hash embeddings"))
        XCTAssertTrue(text.contains("constraint-labeled"))
        XCTAssertTrue(text.contains("nDCG@5 delta"))
        XCTAssertFalse(text.contains("MiniLM-compatible pipeline"))
    }
}

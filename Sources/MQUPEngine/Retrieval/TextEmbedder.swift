import Foundation

/// Deterministic text embedding aligned with `scripts/generate_pois.py`.
/// Production path: Core ML MiniLM-L6-v2 (see models/README.md).
public enum TextEmbedder {
    public static let dimension = 384

    public static func embed(_ text: String) -> [Double] {
        var vector = [Double](repeating: 0, count: dimension)
        let normalized = text.lowercased()
        let tokens = tokenize(normalized)
        for token in tokens {
            accumulate(token: token, into: &vector)
        }
        for index in 0..<max(0, normalized.count - 2) {
            let start = normalized.index(normalized.startIndex, offsetBy: index)
            let end = normalized.index(start, offsetBy: min(3, normalized.count - index))
            accumulate(token: String(normalized[start..<end]), into: &vector)
        }
        return l2Normalize(vector)
    }

    public static func l2Normalize(_ vector: [Double]) -> [Double] {
        let norm = sqrt(vector.reduce(0) { $0 + $1 * $1 })
        guard norm > 0 else { return vector }
        return vector.map { $0 / norm }
    }

    public static func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot = 0.0
        var normA = 0.0
        var normB = 0.0
        for index in 0..<a.count {
            dot += a[index] * b[index]
            normA += a[index] * a[index]
            normB += b[index] * b[index]
        }
        let denom = sqrt(normA) * sqrt(normB)
        guard denom > 0 else { return 0 }
        return dot / denom
    }

    private static func tokenize(_ text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    private static func accumulate(token: String, into vector: inout [Double]) {
        var hash = stableHash(token)
        for _ in 0..<4 {
            let index = Int(hash % UInt64(dimension))
            let sign = (hash & 1) == 0 ? 1.0 : -1.0
            vector[index] += sign
            hash = hash &* 1_103_515_245 &+ 12_345
        }
    }

    private static func stableHash(_ string: String) -> UInt64 {
        var hash: UInt64 = 5381
        for byte in string.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return hash
    }

}

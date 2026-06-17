import Foundation

public final class EmbeddingIndex: Sendable {
    private struct StoredVector {
        let id: UUID
        let values: [Double]
    }

    private let stored: [StoredVector]

    public init(pois: [POI]) {
        stored = pois.map { poi in
            let raw: [Double]
            if let embedding = poi.embedding, embedding.count == TextEmbedder.dimension {
                raw = embedding
            } else {
                let text = [poi.name, poi.category, poi.description].joined(separator: " ")
                raw = TextEmbedder.embed(text)
            }
            return StoredVector(id: poi.id, values: TextEmbedder.l2Normalize(raw))
        }
    }

    public func search(vector: [Double], limit: Int = 50) -> [SemanticHit] {
        let query = TextEmbedder.l2Normalize(vector)
        var top: [(UUID, Double)] = []
        top.reserveCapacity(min(limit, stored.count))

        for entry in stored {
            let score = dot(query, entry.values)
            insertHit(id: entry.id, score: score, into: &top, limit: limit)
        }

        return top.map { SemanticHit(poiID: $0.0, score: $0.1) }
    }

    public func embedQuery(_ text: String) -> [Double] {
        TextEmbedder.embed(text)
    }

    private func dot(_ a: [Double], _ b: [Double]) -> Double {
        var sum = 0.0
        for index in 0..<a.count {
            sum += a[index] * b[index]
        }
        return sum
    }

    private func insertHit(id: UUID, score: Double, into top: inout [(UUID, Double)], limit: Int) {
        if top.count < limit {
            top.append((id, score))
            if top.count == limit {
                top.sort { $0.1 > $1.1 }
            }
            return
        }
        guard score > top[limit - 1].1 else { return }
        top[limit - 1] = (id, score)
        var index = limit - 1
        while index > 0, top[index].1 > top[index - 1].1 {
            top.swapAt(index, index - 1)
            index -= 1
        }
    }
}

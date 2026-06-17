import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public final class BM25Index: @unchecked Sendable {
    private var db: OpaquePointer?
    private let poiByID: [UUID: POI]

    public init(pois: [POI]) throws {
        poiByID = Dictionary(uniqueKeysWithValues: pois.map { ($0.id, $0) })
        try openDatabase()
        try migrate()
        try index(pois: pois)
    }

    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }

    public func search(tokens: [String], limit: Int = 50) throws -> [LexicalHit] {
        let query = tokens.filter { !$0.isEmpty }.joined(separator: " OR ")
        guard !query.isEmpty else { return [] }

        let sql = """
        SELECT poi_id, bm25(pois_fts, 1.2, 0.75) AS score
        FROM pois_fts
        WHERE pois_fts MATCH ?
        ORDER BY score
        LIMIT ?
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw BM25Error.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, query, -1, sqliteTransient)
        sqlite3_bind_int(statement, 2, Int32(limit))

        var hits: [LexicalHit] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let idCString = sqlite3_column_text(statement, 0) else { continue }
            let idString = String(cString: idCString)
            guard let uuid = UUID(uuidString: idString) else { continue }
            let rawScore = sqlite3_column_double(statement, 1)
            // FTS5 bm25: lower (more negative) is better; invert for downstream normalization.
            let score = -rawScore
            hits.append(LexicalHit(poiID: uuid, score: score))
        }
        return hits
    }

    private func openDatabase() throws {
        if sqlite3_open(":memory:", &db) != SQLITE_OK {
            throw BM25Error.openFailed
        }
    }

    private func migrate() throws {
        try exec(sql: """
        CREATE TABLE pois (
            poi_id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            category TEXT NOT NULL,
            description TEXT NOT NULL
        );
        """)

        try exec(sql: """
        CREATE VIRTUAL TABLE pois_fts USING fts5(
            name,
            category,
            description,
            poi_id UNINDEXED,
            tokenize = 'unicode61'
        );
        """)
    }

    private func index(pois: [POI]) throws {
        let insertSQL = """
        INSERT INTO pois_fts (name, category, description, poi_id)
        VALUES (?, ?, ?, ?);
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
            throw BM25Error.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(statement) }

        for poi in pois {
            sqlite3_reset(statement)
            sqlite3_bind_text(statement, 1, poi.name, -1, sqliteTransient)
            sqlite3_bind_text(statement, 2, poi.category, -1, sqliteTransient)
            sqlite3_bind_text(statement, 3, poi.description, -1, sqliteTransient)
            sqlite3_bind_text(statement, 4, poi.id.uuidString, -1, sqliteTransient)
            if sqlite3_step(statement) != SQLITE_DONE {
                throw BM25Error.insertFailed
            }
        }
    }

    private func exec(sql: String) throws {
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            throw BM25Error.execFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    public enum BM25Error: Error {
        case openFailed
        case prepareFailed(String)
        case insertFailed
        case execFailed(String)
    }
}

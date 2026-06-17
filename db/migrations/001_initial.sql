-- MQUP initial schema (reference; runtime uses in-memory SQLite for FTS5)

CREATE TABLE IF NOT EXISTS pois (
    poi_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    description TEXT NOT NULL
);

-- FTS5 virtual table created at runtime by BM25Index.swift

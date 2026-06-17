#!/usr/bin/env python3
"""Regenerate fixture expected states from live SearchCoordinator."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "fixtures"


SWIFT = """
import Foundation
import MQUPEngine

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let pois = try POILoader.load(from: root.appendingPathComponent("data/pois.json"))
let coordinator = try SearchCoordinator(pois: pois)
let fixturesDir = root.appendingPathComponent("fixtures")
let files = try FileManager.default.contentsOfDirectory(at: fixturesDir, includingPropertiesForKeys: nil)
    .filter { $0.pathExtension == "json" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }

for file in files {
    let data = try Data(contentsOf: file)
    var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    let query = json["query"] as! String
    let nowISO = json["nowISO8601"] as! String
    let simulateLoading = json["simulateLoading"] as? Bool ?? false
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    let now = formatter.date(from: nowISO) ?? Date()
    let submission = try coordinator.submit(query: query, now: now, simulateLoading: simulateLoading)
    let state: String
    switch submission.view.state {
    case .golden: state = "golden"
    case .partial: state = "partial"
    case .empty: state = "empty"
    case .loading: state = "loading"
    case .ambiguous: state = "ambiguous"
    }
    json["expectedResultsState"] = state
    let top3 = submission.results.prefix(3).map { $0.poi.id.uuidString.lowercased() }
    json["expectedTop3IDs"] = top3
    let out = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
    try out.write(to: file)
    print("\\(file.lastPathComponent): \\(state)")
}
"""


def main() -> None:
    script = ROOT / ".build" / "fixture_sync.swift"
    script.write_text(SWIFT)
    subprocess.run(
        ["swift", str(script), str(ROOT)],
        cwd=ROOT,
        check=True,
    )
    script.unlink(missing_ok=True)


if __name__ == "__main__":
    main()

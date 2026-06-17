import Foundation

public enum POILoader {
    public enum POILoaderError: Error {
        case missingFile
    }

    public static func load(from url: URL) throws -> [POI] {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode([POI].self, from: data)
    }

    public static func defaultDataURL() -> URL? {
        let candidates = [
            URL(fileURLWithPath: "data/pois.json"),
            URL(fileURLWithPath: "../data/pois.json"),
        ]
        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        return nil
    }
}

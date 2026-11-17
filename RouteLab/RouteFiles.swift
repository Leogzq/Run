import Foundation

enum RouteFiles {
    static func read(_ url: URL) throws -> Route {
        let data = try Data(contentsOf: url)
        guard data.count < 10_000_000 else { throw SessionError.message("路线文件过大。") }
        let root = try JSONSerialization.jsonObject(with: data)
        let object = root as? [String: Any]
        guard let records = (object?["points"] ?? root) as? [[String: Any]] else {
            throw SessionError.message("文件缺少 points 路线点。")
        }
        let points = try records.map { record -> Point in
            // The APK explicitly stores WGS and Baidu coordinates separately.
            // Generic latitude/longitude in APK files are Baidu coordinates.
            guard let lat = number(record, ["wgsLatitude", "gpsLatitude", "wgsLat"]),
                  let lon = number(record, ["wgsLongitude", "gpsLongitude", "wgsLng"]),
                  lat.isFinite, lon.isFinite, abs(lat) <= 90, abs(lon) <= 180 else {
                throw SessionError.message("路线缺少有效 WGS84 坐标。请从原 APK 重新导出包含 wgsLatitude/wgsLongitude 的路线。")
            }
            return Point(latitude: lat, longitude: lon)
        }
        guard points.count >= 2 else { throw SessionError.message("至少需要两个路线点。") }
        return Route(name: object?["name"] as? String ?? url.deletingPathExtension().lastPathComponent, points: points)
    }

    static func write(_ route: Route) throws -> URL {
        let timestamp = Date().timeIntervalSince1970 * 1000
        let records: [[String: Any]] = route.points.map {
            ["wgsLatitude": $0.latitude, "wgsLongitude": $0.longitude, "altitude": 55.0]
        }
        let object: [String: Any] = ["version": 1, "name": route.name, "createdAt": timestamp,
                                     "updatedAt": timestamp, "points": records]
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("route-\(route.id).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func number(_ object: [String: Any], _ keys: [String]) -> Double? {
        for key in keys {
            if let n = object[key] as? NSNumber { return n.doubleValue }
            if let s = object[key] as? String, let n = Double(s) { return n }
        }
        return nil
    }
}

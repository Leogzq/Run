import Foundation

struct Point: Codable, Equatable {
    var latitude: Double
    var longitude: Double

    func distance(to other: Point) -> Double {
        let r = Double.pi / 180
        let a = pow(sin((other.latitude - latitude) * r / 2), 2)
            + cos(latitude * r) * cos(other.latitude * r)
            * pow(sin((other.longitude - longitude) * r / 2), 2)
        return 12_742_000 * asin(sqrt(min(1, max(0, a))))
    }

    func interpolated(to other: Point, fraction: Double) -> Point {
        let delta = (other.longitude - longitude + 540).truncatingRemainder(dividingBy: 360) - 180
        let lon = (longitude + delta * fraction + 540).truncatingRemainder(dividingBy: 360) - 180
        return Point(latitude: latitude + (other.latitude - latitude) * fraction, longitude: lon)
    }
}

struct Route: Codable, Identifiable {
    var id = UUID()
    var name: String
    var points: [Point]
}

struct Track {
    let points: [Point]
    let distances: [Double]
    var length: Double { distances.last ?? 0 }

    init(_ points: [Point]) {
        self.points = points
        var cumulative = points.isEmpty ? [] : [0.0]
        for (start, end) in zip(points, points.dropFirst()) {
            cumulative.append((cumulative.last ?? 0) + start.distance(to: end))
        }
        distances = cumulative
    }

    func point(at meters: Double) -> Point? {
        guard let first = points.first else { return nil }
        if meters <= 0 { return first }
        if meters >= length { return points.last }
        var low = 1
        var high = distances.count - 1
        while low < high {
            let mid = (low + high) / 2
            if distances[mid] < meters { low = mid + 1 } else { high = mid }
        }
        let segment = distances[low] - distances[low - 1]
        guard segment > 0 else { return points[low] }
        return points[low - 1].interpolated(to: points[low], fraction: (meters - distances[low - 1]) / segment)
    }
}

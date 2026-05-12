import CoreGraphics
import Foundation

public struct HoleSketchLayout: Sendable {
    public let centerline: [CGPoint]
    public let outOfBounds: [[CGPoint]]
    public let teePoints: [CGPoint]
    public let greenCenter: CGPoint?

    private let featuresByType: [String: [CourseFeature]]
    private let bounds: CGRect
    private let drawingSize: CGSize

    public init(hole: CourseHole, size: CGSize) {
        let featuresByType = Dictionary(grouping: hole.baseMappingData.features, by: \.featureType)
        let drawingSize = CGSize(width: max(size.width - 20, 1), height: max(size.height - 20, 1))

        var allCoordinates = [[Double]]()
        allCoordinates.append(contentsOf: Self.collectCoordinates(from: hole.baseMappingData.centerline))
        for feature in hole.baseMappingData.features {
            allCoordinates.append(contentsOf: Self.collectCoordinates(from: feature.geometry))
        }
        for line in hole.baseMappingData.outOfBoundsLines {
            if let geometry = line.geometry {
                allCoordinates.append(contentsOf: Self.collectCoordinates(from: geometry))
            }
        }
        allCoordinates.append(contentsOf: hole.tees.map(\.teeCoordinate))
        allCoordinates.append(hole.baseMappingData.green.center)
        if let point = hole.baseMappingData.green.frontCenter {
            allCoordinates.append(point)
        }
        if let point = hole.baseMappingData.green.backCenter {
            allCoordinates.append(point)
        }

        let bounds = Self.makeBounds(from: allCoordinates, size: size)
        let centerline = Self.linePoints(
            from: hole.baseMappingData.centerline,
            in: bounds,
            size: drawingSize
        )
        let outOfBounds: [[CGPoint]] = hole.baseMappingData.outOfBoundsLines.compactMap { line in
            guard let geometry = line.geometry else {
                return nil
            }

            let points = Self.linePoints(from: geometry, in: bounds, size: drawingSize)
            return points.isEmpty ? nil : points
        }
        let teePoints = hole.tees.map {
            Self.project($0.teeCoordinate, in: bounds, size: drawingSize)
        }
        let greenCenter = Self.projectOptional(
            hole.baseMappingData.green.center,
            in: bounds,
            size: drawingSize
        )

        self.featuresByType = featuresByType
        self.drawingSize = drawingSize
        self.bounds = bounds
        self.centerline = centerline
        self.outOfBounds = outOfBounds
        self.teePoints = teePoints
        self.greenCenter = greenCenter
    }

    public func polygonRings(for featureType: String) -> [[CGPoint]] {
        (featuresByType[featureType] ?? [])
            .flatMap { Self.polygonRings(from: $0.geometry, in: bounds, size: drawingSize) }
    }

    public func projectedRings(from geometry: GeoJSONGeometry) -> [[CGPoint]] {
        Self.polygonRings(from: geometry, in: bounds, size: drawingSize)
    }

    private static func makeBounds(from coordinates: [[Double]], size: CGSize) -> CGRect {
        let valid = coordinates.filter { $0.count == 2 }
        let fallback = CGRect(x: 0, y: 0, width: max(size.width, 1), height: max(size.height, 1))

        guard
            let minLon = valid.map({ $0[0] }).min(),
            let maxLon = valid.map({ $0[0] }).max(),
            let minLat = valid.map({ $0[1] }).min(),
            let maxLat = valid.map({ $0[1] }).max()
        else {
            return fallback
        }

        let lonPadding = max((maxLon - minLon) * 0.12, 0.00012)
        let latPadding = max((maxLat - minLat) * 0.12, 0.00012)

        return CGRect(
            x: minLon - lonPadding,
            y: minLat - latPadding,
            width: max((maxLon - minLon) + lonPadding * 2, 0.0002),
            height: max((maxLat - minLat) + latPadding * 2, 0.0002)
        )
    }

    private static func collectCoordinates(from geometry: GeoJSONGeometry) -> [[Double]] {
        switch geometry.type {
        case "LineString":
            return coordinatePairs(from: geometry.coordinates)
        case "Polygon":
            return polygonRingValues(from: geometry.coordinates).flatMap { $0 }
        case "MultiPolygon":
            return multiPolygonRingValues(from: geometry.coordinates).flatMap { $0 }.flatMap { $0 }
        case "Point":
            return coordinatePairs(from: .array([geometry.coordinates])).flatMap { [$0] }
        default:
            return []
        }
    }

    private static func polygonRings(from geometry: GeoJSONGeometry, in bounds: CGRect, size: CGSize) -> [[CGPoint]] {
        switch geometry.type {
        case "Polygon":
            return polygonRingValues(from: geometry.coordinates).compactMap { ring in
                projectedRing(from: ring, in: bounds, size: size)
            }
        case "MultiPolygon":
            return multiPolygonRingValues(from: geometry.coordinates)
                .flatMap { polygon in
                    polygon.compactMap { ring in
                        projectedRing(from: ring, in: bounds, size: size)
                    }
                }
        default:
            return []
        }
    }

    private static func linePoints(from geometry: GeoJSONGeometry, in bounds: CGRect, size: CGSize) -> [CGPoint] {
        guard geometry.type == "LineString" else {
            return []
        }

        return coordinatePairs(from: geometry.coordinates).map { project($0, in: bounds, size: size) }
    }

    private static func projectedRing(from ring: [[Double]], in bounds: CGRect, size: CGSize) -> [CGPoint]? {
        let points = ring
            .filter { $0.count == 2 }
            .map { project($0, in: bounds, size: size) }

        guard points.count >= 3 else {
            return nil
        }

        return points
    }

    private static func coordinatePairs(from value: JSONValue) -> [[Double]] {
        value.arrayValue?.compactMap { point in
            guard
                let values = point.arrayValue?.compactMap(\.numberValue),
                values.count == 2
            else {
                return nil
            }

            return values
        } ?? []
    }

    private static func polygonRingValues(from value: JSONValue) -> [[[Double]]] {
        value.arrayValue?.compactMap { ringValue in
            let points = coordinatePairs(from: ringValue)
            return points.isEmpty ? nil : points
        } ?? []
    }

    private static func multiPolygonRingValues(from value: JSONValue) -> [[[[Double]]]] {
        value.arrayValue?.compactMap { polygonValue in
            let rings = polygonRingValues(from: polygonValue)
            return rings.isEmpty ? nil : rings
        } ?? []
    }

    private static func projectOptional(_ coordinate: [Double]?, in bounds: CGRect, size: CGSize) -> CGPoint? {
        guard let coordinate else {
            return nil
        }

        return project(coordinate, in: bounds, size: size)
    }

    private static func project(_ coordinate: [Double], in bounds: CGRect, size: CGSize) -> CGPoint {
        guard coordinate.count == 2 else {
            return .zero
        }

        let x = (coordinate[0] - bounds.minX) / bounds.width
        let y = 1 - (coordinate[1] - bounds.minY) / bounds.height

        return CGPoint(x: x * size.width, y: y * size.height)
    }
}

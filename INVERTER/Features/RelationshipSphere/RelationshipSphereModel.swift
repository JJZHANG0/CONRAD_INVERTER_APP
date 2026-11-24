import Foundation
import simd

struct SpherePosition: Codable, Hashable {
    var x: Float
    var y: Float
    var z: Float
    init(_ vector: SIMD3<Float>) { x = vector.x; y = vector.y; z = vector.z }
    var vector: SIMD3<Float> { [x, y, z] }
    var isValid: Bool { x.isFinite && y.isFinite && z.isFinite && abs(simd_length(vector) - 1) < 0.002 }
}

/// Pure spatial logic. No screen coordinates, random seed, filtering or rendering dependency.
enum RelationshipSphereLayout {
    static func fibonacci(count: Int) -> [SIMD3<Float>] {
        guard count > 0 else { return [] }
        if count == 1 { return [simd_normalize(SIMD3<Float>(0.72, 0.45, 0.52))] }
        let goldenAngle = Float.pi * (3 - sqrt(5))
        return (0..<count).map { index in
            let y = 1 - 2 * (Float(index) + 0.5) / Float(count)
            let radius = sqrt(max(0, 1 - y * y))
            let angle = goldenAngle * Float(index) + 0.4
            return SIMD3<Float>(cos(angle) * radius, y, sin(angle) * radius)
        }
    }

    /// First allocation is an even Fibonacci sphere; subsequent inserts occupy the largest gap.
    /// Persisted positions are never rebalanced on insertion, deletion, sorting or filtering.
    static func positions(for people: [Person]) -> [UUID: SpherePosition] {
        let sorted = people.sorted { $0.id.uuidString < $1.id.uuidString }
        var result: [UUID: SpherePosition] = [:]
        for person in sorted {
            if let position = person.spherePosition, position.isValid { result[person.id] = position }
        }
        if result.isEmpty {
            return Dictionary(uniqueKeysWithValues: zip(sorted, fibonacci(count: sorted.count)).map { ($0.0.id, SpherePosition($0.1)) })
        }
        guard result.count != sorted.count else { return result }
        let candidates = fibonacci(count: max(512, people.count * 16))
        // Maintain each candidate's nearest distance once, instead of rescanning every
        // existing node for every new contact in a batch.
        var distances = candidates.map { candidate in result.values.reduce(Float(4)) { min($0, simd_distance_squared(candidate, $1.vector)) } }
        for person in sorted where result[person.id] == nil {
            // Stable ID breaks ties without using Swift's randomized Hasher.
            let start = Int(stableHash(person.id) % UInt64(candidates.count))
            var best = candidates[start]
            var bestScore: Float = -.infinity
            for offset in candidates.indices {
                let candidate = candidates[(start + offset) % candidates.count]
                let score = distances[(start + offset) % candidates.count]
                if score > bestScore + 0.000001 { bestScore = score; best = candidate }
            }
            result[person.id] = SpherePosition(best)
            for index in candidates.indices { distances[index] = min(distances[index], simd_distance_squared(candidates[index], best)) }
        }
        return result
    }
    private static func stableHash(_ id: UUID) -> UInt64 {
        id.uuidString.utf8.reduce(UInt64(14695981039346656037)) { ($0 ^ UInt64($1)) &* 1099511628211 }
    }
}

struct RelationshipSphereNode: Identifiable, Equatable {
    let person: Person
    let position: SpherePosition
    let relatedEventCount: Int
    let relationshipID: UUID?
    var id: UUID { person.id }
}

struct RelationshipSphereModel: Equatable {
    let nodes: [RelationshipSphereNode]
    init(people: [Person], events: [LifeEvent], relationships: [Relationship]) {
        // Examples keep their own fixed layout and never write coordinates to a private archive.
        let exampleRotation = simd_quatf(angle: 1.1, axis: [0, 1, 0]) * simd_quatf(angle: 0.4, axis: [1, 0, 0])
        let demoPositions = RelationshipSphereLayout.positions(for: DemoData.people).mapValues { SpherePosition(exampleRotation.act($0.vector)) }
        let realPositions = RelationshipSphereLayout.positions(for: people.filter { !$0.isDemo })
        nodes = people.compactMap { person in
            guard let position = person.isDemo ? demoPositions[person.id] : realPositions[person.id] else { return nil }
            return RelationshipSphereNode(person: person, position: position, relatedEventCount: events.filter { $0.personIDs.contains(person.id) }.count, relationshipID: relationships.first { $0.personID == person.id && $0.otherPersonID == nil }?.id)
        }
    }
}

extension AppStore {
    /// Lazily migrate only the optional layout field. Existing events, IDs and navigation remain intact.
    func prepareSpherePositions() {
        let positions = RelationshipSphereLayout.positions(for: data.people)
        var changed = false
        for index in data.people.indices {
            let position = positions[data.people[index].id]
            if data.people[index].spherePosition != position { data.people[index].spherePosition = position; changed = true }
        }
        if changed { save() }
    }
}

struct SphereMotion {
    static let defaultOrientation = simd_normalize(simd_quatf(angle: -0.12, axis: [1, 0, 0]) * simd_quatf(angle: 0.18, axis: [0, 1, 0]))
    var orientation = defaultOrientation
    var angularVelocity = SIMD2<Float>.zero // X then Y, radians / second
    var zoom: Float = 1
    static let zoomRange: ClosedRange<Float> = 0.76...1.12

    mutating func rotate(delta: SIMD2<Float>) {
        orientation = simd_normalize(simd_quatf(angle: delta.x, axis: [1, 0, 0]) * simd_quatf(angle: delta.y, axis: [0, 1, 0]) * orientation)
    }
    mutating func release(velocity: SIMD2<Float>) {
        let magnitude = simd_length(velocity)
        angularVelocity = magnitude > 2.2 ? velocity / magnitude * 2.2 : velocity
    }
    @discardableResult mutating func tick(dt: Float) -> Bool {
        guard simd_length(angularVelocity) > 0.008 else { angularVelocity = .zero; return false }
        let dt = min(max(dt, 0), 1 / 20)
        let damping: Float = 3.4
        let attenuation = exp(-damping * dt)
        rotate(delta: angularVelocity * ((1 - attenuation) / damping))
        angularVelocity *= attenuation
        return true
    }
    mutating func setZoom(_ zoom: Float) { self.zoom = min(Self.zoomRange.upperBound, max(Self.zoomRange.lowerBound, zoom)) }

    static func fitDistance(size: CGSize) -> Float {
        let aspect = Float(max(size.width, 1) / max(size.height, 1))
        let verticalHalfFOV: Float = 21 * .pi / 180
        let horizontalHalfFOV = atan(tan(verticalHalfFOV) * aspect)
        // Bounding sphere includes the surface markers. Even maximum pinch remains inside the viewport.
        return 1.22 / sin(min(verticalHalfFOV, horizontalHalfFOV))
    }
}

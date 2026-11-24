import Foundation
import Testing
import simd
@testable import INVERTER

@MainActor
struct RelationshipSphereTests {
    private func people(_ count: Int) -> [Person] {
        (0..<count).map { Person(id: UUID(uuidString: String(format: "80000000-0000-0000-0000-%012d", $0 + 1))!, name: "Person \($0)", group: RelationGroup.allCases[$0 % RelationGroup.allCases.count]) }
    }
    @Test(arguments: [0, 1, 5, 20, 50]) func trueSphereCoordinates(count: Int) {
        let records = people(count)
        let positions = RelationshipSphereLayout.positions(for: records)
        #expect(positions.count == count)
        #expect(positions.values.allSatisfy { $0.isValid })
        #expect(RelationshipSphereLayout.positions(for: records.reversed()) == positions)
        if count >= 5 {
            let vectors = Array(positions.values.map(\.vector))
            #expect(vectors.map(\.z).max()! - vectors.map(\.z).min()! > 1)
            #expect(vectors.map(\.x).max()! - vectors.map(\.x).min()! > 1)
            for i in vectors.indices { for j in vectors.indices where i != j { #expect(simd_distance(vectors[i], vectors[j]) > 0.30) } }
        }
    }
    @Test func insertionDeletionAndFilteringPreserveCoordinates() {
        var records = people(20)
        let first = RelationshipSphereLayout.positions(for: records)
        for index in records.indices { records[index].spherePosition = first[records[index].id] }
        records.append(people(21).last!)
        let added = RelationshipSphereLayout.positions(for: records)
        for (id, position) in first { #expect(added[id] == position) }
        let removedID = records.remove(at: 4).id
        let removed = RelationshipSphereLayout.positions(for: records)
        #expect(removed[removedID] == nil)
        for record in records where record.spherePosition != nil { #expect(removed[record.id] == first[record.id]) }
        let family = records.filter { $0.group == .family }
        let filtered = RelationshipSphereLayout.positions(for: family)
        for record in family { #expect(filtered[record.id] == added[record.id]) }
    }
    @Test func oldArchivesDecodeAndCoordinatesSurviveReload() throws {
        let person = people(1)[0]
        let encoded = try JSONEncoder().encode(person)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "spherePosition")
        let legacy = try JSONDecoder().decode(Person.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(legacy.spherePosition == nil)
        let url = URL.temporaryDirectory.appending(path: "sphere-tests-\(UUID()).json")
        let store = AppStore(fileURL: url)
        store.data.people = [legacy]
        store.prepareSpherePositions()
        let reloaded = AppStore(fileURL: url)
        #expect(reloaded.data.people[0].id == person.id)
        #expect(reloaded.data.people[0].spherePosition?.isValid == true)
        #expect(reloaded.data.people[0].spherePosition == store.data.people[0].spherePosition)
    }
    @Test func rotationIsQuaternionAndPreservesSpatialDistances() {
        let points = RelationshipSphereLayout.fibonacci(count: 20)
        var motion = SphereMotion()
        let previous = motion.orientation
        motion.rotate(delta: [0.6, 0.9])
        #expect(simd_length(motion.orientation.vector - previous.vector) > 0.1)
        #expect(abs(simd_length(motion.orientation.vector) - 1) < 0.0001)
        #expect(motion.orientation.act(.zero) == .zero)
        for point in points { #expect(abs(simd_length(motion.orientation.act(point)) - 1) < 0.0001) }
        #expect(abs(simd_distance(points[0], points[1]) - simd_distance(motion.orientation.act(points[0]), motion.orientation.act(points[1]))) < 0.0001)
    }
    @Test func inertiaDecaysAndZoomNeverExceedsViewportFit() {
        var motion = SphereMotion()
        motion.release(velocity: [20, -30])
        #expect(simd_length(motion.angularVelocity) <= 2.201)
        let initial = motion.orientation
        for _ in 0..<240 { motion.tick(dt: 1 / 60) }
        #expect(motion.angularVelocity == .zero)
        #expect(simd_length(initial.vector - motion.orientation.vector) > 0.01)
        motion.setZoom(100)
        #expect(motion.zoom == SphereMotion.zoomRange.upperBound)
        motion.setZoom(-1)
        #expect(motion.zoom == SphereMotion.zoomRange.lowerBound)
        for size in [CGSize(width: 325, height: 365), CGSize(width: 352, height: 365), CGSize(width: 650, height: 365)] {
            let distance = SphereMotion.fitDistance(size: size)
            #expect(distance > 1.22)
            // Tangent of a bounding sphere fits the narrower camera angle even at maximum zoom.
            let angularRadius = asin(1.22 / distance)
            let limitingAngle = min(Float(21 * Double.pi / 180), atan(tan(Float(21 * Double.pi / 180)) * Float(size.width / size.height)))
            #expect(angularRadius <= limitingAngle + 0.00001)
        }
    }
    @Test func relationshipSnapshotUsesExistingPersonEventAndRelationshipIDs() {
        let person = people(1)[0]
        let relation = Relationship(personID: person.id, description: person.group.rawValue)
        let event = LifeEvent(title: "片段", facts: "见面", feeling: .calm, interpretation: "", need: "", nextStep: "", personIDs: [person.id])
        let model = RelationshipSphereModel(people: [person], events: [event], relationships: [relation])
        #expect(model.nodes.first?.id == person.id)
        #expect(model.nodes.first?.relatedEventCount == 1)
        #expect(model.nodes.first?.relationshipID == relation.id)
    }
}

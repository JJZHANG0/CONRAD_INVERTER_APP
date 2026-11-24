import RealityKit
import UIKit
import simd

@MainActor
enum RelationshipGeometry {
    static let ink = UIColor.label
    static let blue = UIColor.secondaryLabel

    static func material(_ color: UIColor, opacity: Float = 1) -> UnlitMaterial {
        var result: UnlitMaterial
        if #available(iOS 18.0, *) {
            result = UnlitMaterial(applyPostProcessToneMap: false)
            result.color = .init(tint: color)
        } else { result = UnlitMaterial(color: color) }
        if opacity < 0.999 { result.blending = .transparent(opacity: .init(floatLiteral: opacity)) }
        return result
    }

    /// A denser sphere grid built as one tube mesh, not hundreds of per-frame entities.
    static func shellMesh() throws -> MeshResource {
        var paths: [[SIMD3<Float>]] = []
        for ring in -4...4 {
            let latitude = Float(ring) * .pi / 10
            paths.append((0...128).map { step in
                let theta = Float(step) / 128 * 2 * .pi
                return SIMD3<Float>(cos(latitude) * cos(theta), sin(latitude), cos(latitude) * sin(theta))
            })
        }
        for meridian in 0..<12 {
            let longitude = Float(meridian) * .pi / 12
            paths.append((0...128).map { step in
                let theta = Float(step) / 128 * 2 * .pi
                return SIMD3<Float>(cos(theta) * cos(longitude), sin(theta), cos(theta) * sin(longitude))
            })
        }
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        let sides = 4
        for path in paths {
            let base = positions.count
            for index in path.indices {
                let point = path[index]
                let tangent = simd_normalize(path[min(index + 1, path.count - 1)] - path[max(0, index - 1)])
                let a = simd_normalize(point)
                let b = simd_normalize(simd_cross(tangent, a))
                for side in 0..<sides {
                    let angle = Float(side) * 2 * .pi / Float(sides)
                    let normal = cos(angle) * a + sin(angle) * b
                    positions.append(point + normal * 0.0022)
                    normals.append(normal)
                }
            }
            for index in 0..<(path.count - 1) {
                for side in 0..<sides {
                    let a = UInt32(base + index * sides + side)
                    let b = UInt32(base + index * sides + (side + 1) % sides)
                    let c = a + UInt32(sides)
                    let d = b + UInt32(sides)
                    indices += [a, c, b, b, c, d]
                }
            }
        }
        var descriptor = MeshDescriptor(name: "RelationshipSphereGrid")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.primitives = .triangles(indices)
        return try MeshResource.generate(from: [descriptor])
    }
}

@MainActor
final class RelationshipNodeEntity {
    let entity: ModelEntity
    let connection: ModelEntity
    var node: RelationshipSphereNode
    var visibility: Float = 1
    var targetVisibility: Float = 1
    var materialKey = -1

    init(node: RelationshipSphereNode, nodeMesh: MeshResource, lineMesh: MeshResource) {
        self.node = node
        entity = ModelEntity(mesh: nodeMesh, materials: [RelationshipGeometry.material(.white)])
        entity.name = "person:\(node.id.uuidString)"
        entity.position = node.position.vector
        entity.collision = CollisionComponent(shapes: [.generateSphere(radius: 1.25)])
        connection = ModelEntity(mesh: lineMesh, materials: [RelationshipGeometry.material(RelationshipGeometry.blue, opacity: 0.3)])
        connection.name = "center-edge:\(node.relationshipID?.uuidString ?? node.id.uuidString)"
        connection.position = node.position.vector / 2
        connection.orientation = simd_quatf(from: [0, 1, 0], to: node.position.vector)
        // Future person-to-person edges can use a separate origin; only center edges are rendered now.
    }
}

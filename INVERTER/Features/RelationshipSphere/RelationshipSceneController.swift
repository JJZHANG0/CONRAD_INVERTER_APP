import SwiftUI
import RealityKit
import Observation
import simd

@MainActor @Observable
final class RelationshipSceneController {
    private(set) var autoRotating = false
    private(set) var error: String?
    @ObservationIgnored private(set) var motion = SphereMotion()
    @ObservationIgnored let rotationRoot = Entity()
    @ObservationIgnored let userCore = ModelEntity()
    @ObservationIgnored private let anchor = AnchorEntity(world: .zero)
    @ObservationIgnored private let camera = PerspectiveCamera()
    @ObservationIgnored private var entities: [UUID: RelationshipNodeEntity] = [:]
    @ObservationIgnored private var entityIDs: [UInt64: UUID] = [:]
    @ObservationIgnored private weak var viewport: RelationshipSceneViewport?
    @ObservationIgnored private var displayLink: CADisplayLink?
    @ObservationIgnored private var displayProxy: SphereDisplayLinkProxy?
    @ObservationIgnored private var lastTime: CFTimeInterval = 0
    @ObservationIgnored private var warmupFrames = 0
    @ObservationIgnored private var nodeMesh: MeshResource?
    @ObservationIgnored private var lineMesh: MeshResource?
    @ObservationIgnored private var nodeMaterials: [[UnlitMaterial]] = []
    @ObservationIgnored private var edgeMaterials: [[UnlitMaterial]] = []
    @ObservationIgnored private var previousDrag = CGSize.zero
    @ObservationIgnored private var pinching = false
    @ObservationIgnored private var dragging = false
    @ObservationIgnored private var pinchStartZoom: Float = 1
    @ObservationIgnored private var resetStart: (simd_quatf, Float, Float)?
    @ObservationIgnored private var active = false
    @ObservationIgnored private var reduceMotion = false
    @ObservationIgnored private var model: RelationshipSphereModel?
    @ObservationIgnored private var filter: RelationGroup?
    @ObservationIgnored private var selectedID: UUID?
    @ObservationIgnored var selectionChanged: ((UUID?) -> Void)?
    @ObservationIgnored private var nodeRadius: Float = 0.115

    @ObservationIgnored private var darkAppearance: Bool?

    func attach(to viewport: RelationshipSceneViewport) {
        self.viewport = viewport
        viewport.controller = self
        let arView = viewport.arView
        arView.environment.background = .color(UIColor.white)
        arView.renderOptions = [.disableMotionBlur, .disableDepthOfField, .disableCameraGrain]
        arView.isAccessibilityElement = false
        arView.accessibilityElementsHidden = true
        rotationRoot.name = "SphereRotationRoot"
        anchor.addChild(rotationRoot)
        camera.camera.fieldOfViewInDegrees = 42
        camera.camera.near = 0.01
        camera.camera.far = 50
        anchor.addChild(camera)
        // The user is a sibling of the rotating network and always remains exactly at the origin.
        userCore.name = "UserCore"
        userCore.model = ModelComponent(mesh: .generateSphere(radius: 0.20), materials: [RelationshipGeometry.material(RelationshipGeometry.ink)])
        userCore.collision = CollisionComponent(shapes: [.generateSphere(radius: 0.20)])
        userCore.position = .zero
        anchor.addChild(userCore)
        let light = DirectionalLight()
        light.light.intensity = 800
        light.look(at: .zero, from: [2, 3, 4], relativeTo: nil)
        anchor.addChild(light)
        do {
            let shell = ModelEntity(mesh: try RelationshipGeometry.shellMesh(), materials: [RelationshipGeometry.material(UIColor(white: 0.62, alpha: 1))])
            shell.name = "LatitudeLongitudeShell"
            rotationRoot.addChild(shell)
        } catch { self.error = L("球面参考线暂时无法加载，人物和交互仍可使用。") }
        nodeMesh = .generateSphere(radius: 1)
        lineMesh = .generateBox(size: [0.0045, 1, 0.0045])
        arView.scene.addAnchor(anchor)
        updateAppearance(dark: viewport.traitCollection.userInterfaceStyle == .dark)
        layoutChanged()
    }

    func updateAppearance(dark: Bool) {
        guard darkAppearance != dark else { return }
        darkAppearance = dark
        let foreground = UIColor(white: dark ? 0.92 : 0.10, alpha: 1)
        let nodeFill = UIColor(white: dark ? 0.17 : 0.98, alpha: 1)
        let selectedFill = UIColor(white: dark ? 0.35 : 0.84, alpha: 1)
        viewport?.arView.environment.background = .color(UIColor(white: dark ? 0.035 : 1, alpha: 1))
        userCore.model?.materials = [RelationshipGeometry.material(foreground)]
        if let shell = rotationRoot.children.first(where: { $0.name == "LatitudeLongitudeShell" }) as? ModelEntity {
            shell.model?.materials = [RelationshipGeometry.material(UIColor(white: dark ? 0.30 : 0.73, alpha: 1))]
        }
        nodeMaterials = []; edgeMaterials = []
        for state in 0..<3 {
            nodeMaterials.append((0...32).map { RelationshipGeometry.material(state == 1 ? selectedFill : nodeFill, opacity: Float($0) / 32) })
            for bucket in 0...5 {
                let edgeColor = bucket == 0 ? foreground : ConnectionCloseness(rawValue: bucket - 1)!.uiColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: dark ? .dark : .light))
                edgeMaterials.append((0...32).map { RelationshipGeometry.material(edgeColor, opacity: Float($0) / 32 * (state == 1 ? 1 : state == 2 ? 0.24 : bucket == 0 ? 0.32 : 0.78)) })
            }
        }
        for item in entities.values { item.materialKey = -1 }
        viewport?.labels.applyAppearance(dark: dark)
        layoutChanged()
    }

    func update(model: RelationshipSphereModel, filter: RelationGroup?, selectedID: UUID?, active: Bool, reduceMotion: Bool) {
        self.reduceMotion = reduceMotion
        if reduceMotion { autoRotating = false; motion.angularVelocity = .zero }
        let modelChanged = self.model != model
        let filterChanged = self.filter != filter
        if modelChanged { reconcile(model) }
        self.model = model
        self.filter = filter
        self.selectedID = selectedID
        for item in entities.values {
            item.targetVisibility = filter == nil || item.node.person.group == filter ? 1 : 0
            // Filtering stops hit testing immediately, while visuals fade over a short interval.
            item.entity.collision?.filter.mask = item.targetVisibility > 0 ? .all : []
            item.entity.collision?.filter.group = item.targetVisibility > 0 ? .default : []
            if reduceMotion { item.visibility = item.targetVisibility }
        }
        if self.active != active {
            self.active = active
            viewport?.arView.isHidden = !active
            anchor.isEnabled = active
            if !active { suspend() }
            else { warmupFrames = 4; startFrames() }
        }
        if active {
            if modelChanged || filterChanged { warmupFrames = 3; startFrames() }
            applyTransformsAndProject()
        }
    }

    private func reconcile(_ model: RelationshipSphereModel) {
        guard let nodeMesh, let lineMesh else { return }
        let validIDs = Set(model.nodes.map(\.id))
        for id in Array(entities.keys) where !validIDs.contains(id) {
            if let removed = entities.removeValue(forKey: id) {
                entityIDs.removeValue(forKey: removed.entity.id)
                removed.entity.removeFromParent()
                removed.connection.removeFromParent()
            }
        }
        nodeRadius = model.nodes.count <= 8 ? 0.115 : model.nodes.count <= 32 ? 0.085 : 0.065
        for node in model.nodes {
            if let existing = entities[node.id] { existing.node = node; existing.entity.position = node.position.vector }
            else {
                let entity = RelationshipNodeEntity(node: node, nodeMesh: nodeMesh, lineMesh: lineMesh)
                entities[node.id] = entity
                entityIDs[entity.entity.id] = node.id
                rotationRoot.addChild(entity.connection)
                rotationRoot.addChild(entity.entity)
            }
            entities[node.id]?.entity.scale = SIMD3<Float>(repeating: nodeRadius)
        }
        viewport?.labels.reconcile(ids: validIDs)
        viewport?.reconcileAccessibility(ids: validIDs)
    }

    func layoutChanged() {
        guard active else { return }
        warmupFrames = 4
        applyTransformsAndProject()
        startFrames()
    }
    func dragChanged(_ translation: CGSize) {
        guard active, !pinching else { return }
        autoRotating = false
        dragging = true
        motion.angularVelocity = .zero
        resetStart = nil
        let delta = SIMD2<Float>(Float(translation.height - previousDrag.height), Float(translation.width - previousDrag.width)) * 0.007
        previousDrag = translation
        motion.rotate(delta: delta)
        applyTransformsAndProject()
    }
    func dragEnded(predicted: CGSize, actual: CGSize) {
        previousDrag = .zero
        guard dragging else { return }
        dragging = false
        guard !pinching, !reduceMotion else { return }
        let velocity = SIMD2<Float>(Float(predicted.height - actual.height), Float(predicted.width - actual.width)) * (0.007 / 0.25)
        motion.release(velocity: velocity)
        startFrames()
    }
    func pinchChanged(_ scale: CGFloat) {
        guard active else { return }
        if !pinching { pinching = true; dragging = false; pinchStartZoom = motion.zoom }
        autoRotating = false
        motion.angularVelocity = .zero
        resetStart = nil
        motion.setZoom(pinchStartZoom * Float(scale))
        applyTransformsAndProject()
    }
    func pinchEnded() { pinching = false; previousDrag = .zero }

    func select(at point: CGPoint) {
        guard active, let view = viewport?.arView else { return }
        autoRotating = false
        motion.angularVelocity = .zero
        // RealityKit casts a camera ray and returns the nearest collision entity, respecting depth.
        let hit = view.hitTest(point, query: .nearest, mask: .all).first?.entity
        if hit === userCore { reset(); return }
        let id = hit.flatMap { entityIDs[$0.id] }
        select(id: id)
    }
    func select(id: UUID?) {
        guard id == nil || entities[id!]?.targetVisibility == 1 else { return }
        motion.angularVelocity = .zero
        autoRotating = false
        selectedID = id
        selectionChanged?(id)
        UISelectionFeedbackGenerator().selectionChanged()
        applyTransformsAndProject()
    }
    func reset() {
        autoRotating = false
        motion.angularVelocity = .zero
        previousDrag = .zero
        pinching = false
        if reduceMotion { motion = SphereMotion(); applyTransformsAndProject() }
        else { resetStart = (motion.orientation, motion.zoom, 0); startFrames() }
    }
    func toggleAutoRotation() {
        guard active, !reduceMotion else { return }
        autoRotating.toggle()
        motion.angularVelocity = .zero
        resetStart = nil
        if autoRotating { startFrames() }
    }
    func suspend() {
        active = false
        viewport?.arView.isHidden = true
        anchor.isEnabled = false
        dragging = false
        autoRotating = false
        motion.angularVelocity = .zero
        resetStart = nil
        previousDrag = .zero
        pinching = false
        stopFrames()
    }
    func dispose() {
        suspend()
        selectionChanged = nil
        viewport?.arView.scene.removeAnchor(anchor)
        anchor.children.removeAll()
        rotationRoot.children.removeAll()
        entities.removeAll()
        entityIDs.removeAll()
        nodeMaterials.removeAll()
        edgeMaterials.removeAll()
        model = nil
        active = false
        viewport = nil
    }

    private func startFrames() {
        guard active, displayLink == nil else { return }
        let proxy = SphereDisplayLinkProxy(controller: self)
        let link = CADisplayLink(target: proxy, selector: #selector(SphereDisplayLinkProxy.frame(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayProxy = proxy
        displayLink = link
        lastTime = 0
    }
    private func stopFrames() {
        displayLink?.invalidate()
        displayLink = nil
        displayProxy = nil
        lastTime = 0
    }
    fileprivate func frame(_ link: CADisplayLink) {
        guard active else { stopFrames(); return }
        let dt = Float(lastTime == 0 ? 1 / 60 : min(link.timestamp - lastTime, 1 / 20))
        lastTime = link.timestamp
        var needsMore = false
        if let (orientation, zoom, elapsed) = resetStart {
            let elapsed = elapsed + dt
            let t = min(1, elapsed / 0.45)
            let eased = t * t * (3 - 2 * t)
            motion.orientation = simd_slerp(orientation, SphereMotion.defaultOrientation, eased)
            motion.zoom = zoom + (1 - zoom) * eased
            resetStart = t < 1 ? (orientation, zoom, elapsed) : nil
            needsMore = t < 1
        } else if autoRotating && !reduceMotion {
            motion.rotate(delta: [0, dt * 0.065])
            needsMore = true
        } else if !reduceMotion { needsMore = motion.tick(dt: dt) }
        for item in entities.values where abs(item.visibility - item.targetVisibility) > 0.001 {
            let direction: Float = item.targetVisibility > item.visibility ? 1 : -1
            item.visibility = min(1, max(0, item.visibility + direction * dt / 0.22))
            needsMore = true
        }
        applyTransformsAndProject()
        if warmupFrames > 0 { warmupFrames -= 1; needsMore = true }
        if !needsMore { stopFrames() }
    }

    private func applyTransformsAndProject() {
        guard let viewport, viewport.bounds.width > 0, viewport.bounds.height > 0, !nodeMaterials.isEmpty else { return }
        rotationRoot.orientation = motion.orientation
        let distance = SphereMotion.fitDistance(size: viewport.bounds.size) * 1.12 / motion.zoom
        camera.look(at: .zero, from: [0, 0, distance], relativeTo: nil)
        var projected: [ProjectedRelationshipNode] = []
        for item in entities.values {
            item.entity.isEnabled = item.visibility > 0.001
            item.connection.isEnabled = item.visibility > 0.001
            guard item.visibility > 0.001 else { continue }
            let world = item.entity.position(relativeTo: nil)
            let depth = min(1, max(0, (world.z + 1) / 2))
            let state = selectedID == nil ? 0 : selectedID == item.node.id ? 1 : 2
            let alpha = item.visibility * (0.40 + 0.60 * depth) * (state == 2 ? 0.48 : 1)
            let bin = min(32, max(0, Int((alpha * 32).rounded())))
            let colorBucket = item.node.person.closeness.map { $0.rawValue + 1 } ?? 0
            let materialKey = (state * 6 + colorBucket) * 33 + bin
            if item.materialKey != materialKey {
                item.entity.model?.materials = [nodeMaterials[state][bin]]
                item.connection.model?.materials = [edgeMaterials[state * 6 + colorBucket][bin]]
                item.materialKey = materialKey
            }
            guard let point = viewport.arView.project(world), let edge = viewport.arView.project(world + SIMD3<Float>(nodeRadius, 0, 0)) else { continue }
            projected.append(ProjectedRelationshipNode(node: item.node, point: point, depth: world.z, radius: abs(edge.x - point.x), opacity: CGFloat(alpha), selected: state == 1))
        }
        let center = viewport.arView.project(.zero) ?? CGPoint(x: viewport.bounds.midX, y: viewport.bounds.midY)
        let edge = viewport.arView.project([0.2, 0, 0]) ?? CGPoint(x: center.x + 25, y: center.y)
        viewport.labels.update(projected, center: center, coreRadius: abs(edge.x - center.x))
        viewport.updateAccessibility()
        // Diagnostic values are semantic accessibility metadata, not visible product UI.
        if ProcessInfo.processInfo.arguments.contains("--uitesting") { viewport.setDiagnosticValue(String(format: "nodes:%d; q:%.3f,%.3f,%.3f,%.3f; zoom:%.3f", entities.values.filter { $0.targetVisibility > 0 }.count, motion.orientation.vector.x, motion.orientation.vector.y, motion.orientation.vector.z, motion.orientation.vector.w, motion.zoom)) }
    }
}

@MainActor
private final class SphereDisplayLinkProxy: NSObject {
    weak var controller: RelationshipSceneController?
    init(controller: RelationshipSceneController) { self.controller = controller }
    @objc func frame(_ link: CADisplayLink) { controller?.frame(link) }
}

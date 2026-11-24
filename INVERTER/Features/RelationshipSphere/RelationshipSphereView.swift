import SwiftUI
import RealityKit

struct RelationshipSphereView: View {
    let model: RelationshipSphereModel
    let filter: RelationGroup?
    @Binding var selection: UUID?
    var enabled = true
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var controller = RelationshipSceneController()
    @State private var visible = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RelationshipSceneContainer(controller: controller, model: model, filter: filter, selectedID: selection, active: enabled && visible && scenePhase == .active, reduceMotion: reduceMotion, select: { selection = $0 })
                .contentShape(Rectangle())
                // A drag that begins in the sphere owns both axes; the surrounding page still scrolls elsewhere.
                .highPriorityGesture(DragGesture(minimumDistance: 5, coordinateSpace: .local)
                    .onChanged { controller.dragChanged($0.translation) }
                    .onEnded { controller.dragEnded(predicted: $0.predictedEndTranslation, actual: $0.translation) })
                .simultaneousGesture(MagnificationGesture()
                    .onChanged { controller.pinchChanged($0) }
                    .onEnded { _ in controller.pinchEnded() })
                .simultaneousGesture(SpatialTapGesture(count: 2).exclusively(before: SpatialTapGesture(count: 1))
                    .onEnded { value in
                        switch value {
                        case .first: controller.reset()
                        case .second(let tap): controller.select(at: tap.location)
                        }
                    })
            HStack(spacing: 9) {
                if !reduceMotion {
                    Button { controller.toggleAutoRotation() } label: {
                        Image(systemName: controller.autoRotating ? "pause" : "rotate.3d").frame(width: 35, height: 35)
                    }.accessibilityLabel(controller.autoRotating ? L("暂停缓慢旋转") : L("开始缓慢旋转")).accessibilityIdentifier("sphere.auto")
                }
                Button { controller.reset() } label: { Image(systemName: "arrow.counterclockwise").frame(width: 35, height: 35) }
                    .accessibilityLabel(L("复位关系球")).accessibilityIdentifier("sphere.reset")
            }.font(.system(size: 13, weight: .medium)).background(Color.surface.opacity(0.94), in: Capsule()).padding(4).opacity(selection == nil ? 1 : 0).allowsHitTesting(selection == nil).accessibilityHidden(selection != nil)
            if let error = controller.error {
                Text(error).font(.caption2).foregroundStyle(Color.muted).padding(8).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }.onAppear { visible = true }
            .onDisappear { visible = false; controller.suspend() }
            .onChange(of: scenePhase) { _, phase in if phase != .active { controller.suspend() } }
    }
}

private struct RelationshipSceneContainer: UIViewRepresentable {
    @Environment(\.colorScheme) private var colorScheme
    let controller: RelationshipSceneController
    let model: RelationshipSphereModel
    let filter: RelationGroup?
    let selectedID: UUID?
    let active: Bool
    let reduceMotion: Bool
    let select: (UUID?) -> Void
    func makeUIView(context: Context) -> RelationshipSceneViewport {
        let view = RelationshipSceneViewport()
        controller.selectionChanged = select
        controller.attach(to: view)
        return view
    }
    func updateUIView(_ view: RelationshipSceneViewport, context: Context) {
        controller.selectionChanged = select
        controller.updateAppearance(dark: colorScheme == .dark)
        controller.update(model: model, filter: filter, selectedID: selectedID, active: active, reduceMotion: reduceMotion)
    }
    static func dismantleUIView(_ view: RelationshipSceneViewport, coordinator: ()) { view.controller?.dispose() }
}

@MainActor
final class RelationshipSceneViewport: UIView {
    let arView = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
    let labels = RelationshipLabelOverlay()
    weak var controller: RelationshipSceneController?
    private var nodes: [UUID: RelationshipAccessibilityNode] = [:]
    private lazy var diagnostics: UIAccessibilityElement = {
        let value = UIAccessibilityElement(accessibilityContainer: self)
        value.accessibilityIdentifier = "sphere.state"
        value.accessibilityLabel = "Sphere test state"
        value.accessibilityTraits = .staticText
        value.accessibilityFrameInContainerSpace = CGRect(x: 1, y: 1, width: 1, height: 1)
        return value
    }()
    func setDiagnosticValue(_ value: String) { diagnostics.accessibilityValue = value }
    private lazy var coreAccessibility: RelationshipAccessibilityNode = {
        let element = RelationshipAccessibilityNode(accessibilityContainer: self)
        element.accessibilityLabel = L("我，返回关系全景")
        element.accessibilityIdentifier = "sphere.core"
        element.accessibilityTraits = .button
        element.activate = { [weak self] in self?.controller?.reset() }
        return element
    }()
    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        addSubview(arView)
        addSubview(labels)
        isAccessibilityElement = false
        accessibilityIdentifier = "sphere.viewport"
        accessibilityLabel = L("三维关系球")
        accessibilityContainerType = .semanticGroup
        shouldGroupAccessibilityChildren = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        arView.frame = bounds
        labels.frame = bounds
        controller?.layoutChanged()
    }
    func reconcileAccessibility(ids: Set<UUID>) {
        for id in Array(nodes.keys) where !ids.contains(id) { nodes.removeValue(forKey: id) }
        for id in ids where nodes[id] == nil {
            let element = RelationshipAccessibilityNode(accessibilityContainer: self)
            element.accessibilityTraits = .button
            element.activate = { [weak self] in self?.controller?.select(id: id) }
            nodes[id] = element
        }
    }
    func updateAccessibility() {
        var elements: [UIAccessibilityElement] = []
        for item in labels.accessibleNodes {
            guard let element = nodes[item.node.id] else { continue }
            element.accessibilityLabel = L("\(item.node.person.name)，\(item.node.person.group.label)，\(item.node.relatedEventCount) 次记录") + " · " + (item.node.person.closeness?.label ?? L("亲密程度未标注"))
            element.accessibilityIdentifier = "person.\(item.node.person.name)"
            element.accessibilityTraits = item.selected ? [.button, .selected] : .button
            let diameter = max(24, item.radius * 2)
            element.accessibilityFrameInContainerSpace = CGRect(x: item.point.x - diameter / 2, y: item.point.y - diameter / 2, width: diameter, height: diameter)
            elements.append(element)
        }
        coreAccessibility.accessibilityFrameInContainerSpace = CGRect(x: bounds.midX - 23, y: bounds.midY - 23, width: 46, height: 46)
        elements.append(coreAccessibility)
        if ProcessInfo.processInfo.arguments.contains("--uitesting") { elements.append(diagnostics) }
        accessibilityElements = elements
    }
}

#if DEBUG
/// Launch-only deterministic test fixtures; never activated during ordinary app use.
@MainActor
enum RelationshipSphereFixtures {
    static func installIfRequested(in store: AppStore) {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--uitesting"), let flag = arguments.first(where: { $0.hasPrefix("--sphere-count=") }), let count = Int(flag.split(separator: "=").last ?? ""), [0, 1, 5, 20, 50].contains(count) else { return }
        store.data.showDemo = false
        store.data.people = (0..<count).map { index in
            Person(id: UUID(uuidString: String(format: "90000000-0000-0000-0000-%012d", index + 1))!, name: String(format: "人物%02d", index + 1), group: RelationGroup.allCases[index % RelationGroup.allCases.count])
        }
        store.data.relationships = store.data.people.map { Relationship(personID: $0.id, description: $0.group.label) }
        store.prepareSpherePositions()
    }
}
#endif

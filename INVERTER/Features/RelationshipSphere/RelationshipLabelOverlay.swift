import UIKit

struct ProjectedRelationshipNode {
    let node: RelationshipSphereNode
    let point: CGPoint
    let depth: Float
    let radius: CGFloat
    let opacity: CGFloat
    let selected: Bool
}

/// Screen-facing typography positioned ONLY from ARView.project(worldPosition).
/// The circles beneath it remain RealityKit geometry and use the renderer's depth buffer.
@MainActor
final class RelationshipLabelOverlay: UIView {
    private final class Billboard: UIView {
        let initials = UILabel()
        let avatar = UIImageView()
        var avatarData: Data?
        let name = UILabel()
        let category = UILabel()
        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            initials.textAlignment = .center
            initials.textColor = RelationshipGeometry.ink
            initials.layer.borderWidth = 0.8
            name.textAlignment = .center
            name.textColor = RelationshipGeometry.ink
            category.textAlignment = .center
            category.textColor = .secondaryLabel
            avatar.contentMode = .scaleAspectFill; avatar.clipsToBounds = true
            [initials, avatar, name, category].forEach(addSubview)
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    }
    private var billboards: [UUID: Billboard] = [:]
    private let core = UILabel()
    private let halo = UIView()
    var accessibleNodes: [ProjectedRelationshipNode] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
        halo.layer.borderWidth = 1
        halo.layer.borderColor = RelationshipGeometry.blue.withAlphaComponent(0.07).cgColor
        halo.layer.shadowColor = RelationshipGeometry.blue.cgColor
        halo.layer.shadowOpacity = 0.08
        halo.layer.shadowRadius = 10
        halo.layer.shadowOffset = .zero
        addSubview(halo)
        core.numberOfLines = 2
        core.textAlignment = .center
        core.textColor = .white
        addSubview(core)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func applyAppearance(dark: Bool) {
        core.textColor = dark ? .black : .white
        halo.layer.borderColor = UIColor.label.resolvedColor(with: traitCollection).withAlphaComponent(0.12).cgColor
    }

    func reconcile(ids: Set<UUID>) {
        for id in Array(billboards.keys) where !ids.contains(id) { billboards.removeValue(forKey: id)?.removeFromSuperview() }
        for id in ids where billboards[id] == nil {
            let billboard = Billboard()
            billboards[id] = billboard
            addSubview(billboard)
        }
    }

    func update(_ nodes: [ProjectedRelationshipNode], center: CGPoint, coreRadius: CGFloat) {
        let coreRect = CGRect(x: center.x - coreRadius, y: center.y - coreRadius, width: coreRadius * 2, height: coreRadius * 2)
        core.frame = coreRect
        let text = NSMutableAttributedString(string: L("我\n"), attributes: [.font: UIFont.systemFont(ofSize: max(16, coreRadius * 0.72), weight: .medium)])
        text.append(NSAttributedString(string: L("自己"), attributes: [.font: UIFont.monospacedSystemFont(ofSize: max(6, coreRadius * 0.26), weight: .regular), .kern: 1.2]))
        core.attributedText = text
        halo.frame = coreRect.insetBy(dx: -9, dy: -9)
        halo.layer.cornerRadius = halo.frame.width / 2
        // Marker visibility honors the projected near-to-far order and the opaque user core.
        let frontToBack = nodes.sorted { $0.depth > $1.depth }
        var markerRects: [CGRect] = []
        var visible: [ProjectedRelationshipNode] = []
        for item in frontToBack {
            guard let billboard = billboards[item.node.id] else { continue }
            billboard.isHidden = true
            let point = item.point
            let inBounds = bounds.insetBy(dx: -2, dy: -2).contains(point)
            let behindCore = item.depth < 0 && hypot(point.x - center.x, point.y - center.y) < coreRadius + item.radius * 0.3
            let behindNode = markerRects.contains { $0.contains(point) }
            guard item.opacity > 0.04, inBounds, !behindCore, !behindNode else { continue }
            let radius = max(4, item.radius)
            markerRects.append(CGRect(x: point.x - radius * 0.8, y: point.y - radius * 0.8, width: radius * 1.6, height: radius * 1.6))
            visible.append(item)
            billboard.frame = bounds
            billboard.isHidden = false
            billboard.alpha = item.opacity
            billboard.initials.frame = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
            billboard.initials.layer.cornerRadius = radius
            let ringColor = (item.node.person.closeness?.uiColor ?? RelationshipGeometry.blue).resolvedColor(with: traitCollection)
            billboard.initials.layer.borderColor = ringColor.withAlphaComponent(item.selected ? 1 : 0.8).cgColor
            billboard.initials.layer.borderWidth = item.selected ? 1.7 : 0.8
            if billboard.avatarData != item.node.person.avatarData {
                billboard.avatarData = item.node.person.avatarData
                billboard.avatar.image = item.node.person.avatarData.flatMap { UIImage(data: $0) }
            }
            billboard.avatar.frame = billboard.initials.frame
            billboard.avatar.layer.cornerRadius = radius
            billboard.avatar.layer.borderColor = billboard.initials.layer.borderColor
            billboard.avatar.layer.borderWidth = item.selected ? 2 : 1.2
            billboard.avatar.isHidden = billboard.avatar.image == nil
            billboard.initials.text = billboard.avatar.image == nil && radius >= 7 ? item.node.person.initials : nil
            billboard.initials.font = .systemFont(ofSize: min(16, max(9, radius * 0.83)), weight: .medium)
            billboard.name.isHidden = true
            billboard.category.isHidden = true
        }
        for id in Set(billboards.keys).subtracting(Set(visible.map { $0.node.id })) { billboards[id]?.isHidden = true }

        // Prioritize selected/front labels; reserve the core and all marker footprints.
        // Try below then above, hide if neither fits. Do not detach labels from their 3D node.
        var occupied = markerRects + [coreRect.insetBy(dx: -8, dy: -8)]
        let labelOrder = visible.sorted { lhs, rhs in lhs.selected != rhs.selected ? lhs.selected : lhs.depth > rhs.depth }
        for item in labelOrder {
            guard item.selected || item.depth > -0.12, let billboard = billboards[item.node.id] else { continue }
            billboard.name.font = .systemFont(ofSize: item.selected ? 13 : 11, weight: .medium)
            billboard.name.text = item.node.person.name
            billboard.category.font = .systemFont(ofSize: 8, weight: .regular)
            billboard.category.text = L("\(item.node.person.group.label) · \(item.node.relatedEventCount) 次")
            let width = min(bounds.width - 12, max(64, min(170, max(billboard.name.intrinsicContentSize.width, billboard.category.intrinsicContentSize.width) + 10)))
            let height: CGFloat = 32
            let x = min(bounds.width - width - 4, max(4, item.point.x - width / 2))
            let candidates = [CGRect(x: x, y: item.point.y + item.radius + 5, width: width, height: height), CGRect(x: x, y: item.point.y - item.radius - height - 5, width: width, height: height)]
            if let rect = candidates.first(where: { candidate in bounds.insetBy(dx: 2, dy: 2).contains(candidate) && !occupied.contains(where: { $0.intersects(candidate) }) }) {
                place(billboard, rect: rect)
                occupied.append(rect.insetBy(dx: -3, dy: -2))
            }
        }
        // Keep all typography in actual depth order. A selected rear node never jumps in front geometrically.
        for item in visible.reversed() { if let billboard = billboards[item.node.id] { bringSubviewToFront(billboard) } }
        bringSubviewToFront(core)
        core.isHidden = visible.contains { $0.depth > 0.2 && hypot($0.point.x - center.x, $0.point.y - center.y) < $0.radius * 0.8 }
        accessibleNodes = visible
    }
    private func place(_ billboard: Billboard, rect: CGRect) {
        billboard.name.frame = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 17)
        billboard.category.frame = CGRect(x: rect.minX, y: rect.minY + 19, width: rect.width, height: 12)
        billboard.name.isHidden = false
        billboard.category.isHidden = false
    }
}

@MainActor
final class RelationshipAccessibilityNode: UIAccessibilityElement {
    var activate: (() -> Void)?
    override func accessibilityActivate() -> Bool { activate?(); return true }
}

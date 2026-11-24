import SwiftUI

struct ConnectionsView: View {
    @Environment(AppStore.self) private var store
    @State private var group: RelationGroup?
    @State private var selected: Person?
    @State private var adding = false
    @State private var importing = false
    @State private var importNotice: String?
    @State private var focusedPersonID: UUID?
    @State private var prepared = false
    private var filtered: [Person] { store.people.filter { group == nil || $0.group == group } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                PageHeading(eyebrow: L("我们之间"), title: L("关系，让理解发生。"), subtitle: L("从一次真实的互动，慢慢走近彼此。"))
                HStack(spacing: 12) {
                    Button { adding = true } label: { Label(L("添加关系"), systemImage: "plus").frame(maxWidth: .infinity).padding(.vertical, 14).background(Color.ink, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(Color.paper) }.accessibilityIdentifier("connections.add")
                    Button { importing = true } label: { Label(L("导入通讯录"), systemImage: "person.crop.rectangle.stack").frame(maxWidth: .infinity).padding(.vertical, 14).background(Color.surface, in: RoundedRectangle(cornerRadius: 14)) }.accessibilityIdentifier("connections.import")
                }.font(.system(size: 13, weight: .medium)).buttonStyle(.plain)
                if let importNotice { Text(importNotice).font(.caption).foregroundStyle(Color.muted).accessibilityIdentifier("contacts.result") }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        filterButton(L("全部"), value: nil)
                        ForEach([RelationGroup.uncategorized] + RelationGroup.allCases.filter { $0 != .uncategorized }) { relation in filterButton(relation.label, value: relation) }
                    }
                }
                RelationshipSphereView(model: RelationshipSphereModel(people: store.people, events: store.events, relationships: store.data.relationships), filter: group, selection: $focusedPersonID, enabled: selected == nil && !adding && !importing)
                    .frame(height: 365)
                    .overlay(alignment: .bottom) { selectionPanel }
                    .background(RadialGradient(colors: [Color.paper, Color.paper], center: .center, startRadius: 40, endRadius: 230))
                HStack(spacing: 5) { Image(systemName: "hand.draw"); Text(L("拖动旋转 · 双指缩放 · 双击复位")) }.font(.system(size: 10)).foregroundStyle(Color.muted).frame(maxWidth: .infinity)
                HStack { Text("\(filtered.count)").font(.system(size: 28, weight: .light, design: .rounded)); Text(L("个连接\(store.data.showDemo ? L(" · 含示例人物") : "")")).font(.system(size: 11)).foregroundStyle(Color.muted); Spacer(); Image(systemName: "point.3.connected.trianglepath.dotted").font(.system(size: 25, weight: .ultraLight)).foregroundStyle(Color.crystal) }.padding(.top, 5)
                VStack(spacing: 10) {
                    HStack { Text(L("冰蓝 · 较淡")); Spacer(); Text(L("暖粉 · 亲密")) }.font(.system(size: 11)).foregroundStyle(Color.muted)
                    Capsule().fill(LinearGradient(colors: ConnectionCloseness.allCases.map(\.color), startPoint: .leading, endPoint: .trailing)).frame(height: 3)
                    Text(L("颜色来自你标注的亲密程度 · 灰色为未标注")) .font(.system(size: 10)).foregroundStyle(Color.muted)
                }.accessibilityElement(children: .combine)
                Notice(text: L("节点位置仅用于展示。关系分类与亲密程度都由你设置，可以随时调整。"))
                Divider()
                if filtered.isEmpty {
                    EmptySpace(icon: "person.crop.circle.badge.plus", title: L("从一个重要的人开始"), message: L("添加人物，再将真实经历关联到他们。"))
                    Button { adding = true } label: { Text(L("添加一个人物")) }.buttonStyle(PrimaryButtonStyle())
                } else {
                    SectionHeading(title: L("我与他们"), subtitle: L("我的连接"))
                    ForEach(filtered) { person in
                        Button { selected = person } label: { PersonRow(person: person, events: store.events(for: person)) }.buttonStyle(.plain).accessibilityIdentifier("connections.person.\(person.name)")
                    }
                }
                NavigationLink { RelationshipInsightsView() } label: {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack { Eyebrow(text: L("关系洞察")); Spacer(); Image(systemName: "arrow.up.right") }
                        Text(L("看见互动中的线索")).font(.system(size: 21, weight: .medium))
                        Text(L("频率、感受，和那些值得再聊聊的事。")) .font(.system(size: 12)).foregroundStyle(Color.muted)
                    }.surface()
                }.buttonStyle(.plain)
            }.padding(25).padding(.top, 12).frame(maxWidth: 720).frame(maxWidth: .infinity)
        }.pageStyle().toolbar(.hidden, for: .navigationBar)
            .onAppear {
                if !prepared {
                    #if DEBUG
                    RelationshipSphereFixtures.installIfRequested(in: store)
                    #endif
                    prepared = true
                }
                store.prepareSpherePositions()
            }
            .onChange(of: store.people) { _, _ in
                store.prepareSpherePositions()
                if let id = focusedPersonID, !filtered.contains(where: { $0.id == id }) { focusedPersonID = nil }
            }
            .onChange(of: group) { _, _ in
                if let id = focusedPersonID, !filtered.contains(where: { $0.id == id }) { focusedPersonID = nil }
            }
            .sheet(isPresented: $adding) { PersonEditor() }
            .sheet(isPresented: $importing) { ContactImportView { result in group = nil; importNotice = L("已导入") + " \(result.added) " + L("个人物，已加入你的连接。") } }
            .navigationDestination(item: $selected) { person in PersonDetailView(personID: person.id) }
    }
    @ViewBuilder private var selectionPanel: some View {
        if let id = focusedPersonID, let person = store.person(id) {
            HStack(spacing: 10) {
                Button { selected = person } label: {
                    HStack(spacing: 12) {
                        PersonAvatar(person: person, size: 38)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(person.name).font(.system(size: 16, weight: .medium)).fixedSize(horizontal: false, vertical: true)
                            Text(L("\(person.group.label) · \(store.events(for: person).count) 次记录\(person.isDemo ? L(" · 示例") : "")")).font(.system(size: 10)).foregroundStyle(Color.muted)
                            Text(L("查看人物档案 ↗")).font(.system(size: 10, weight: .medium)).foregroundStyle(Color.crystal)
                        }
                        Spacer(minLength: 0)
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("sphere.details")
                Button { focusedPersonID = nil } label: { Image(systemName: "xmark").font(.system(size: 12)).frame(width: 32, height: 40) }.accessibilityLabel(L("取消人物选中"))
            }.padding(14).background(Color.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.line.opacity(0.6), lineWidth: 0.7))
                .padding(.horizontal, 3).padding(.bottom, 2)
        }
    }
    private func filterButton(_ title: String, value: RelationGroup?) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.2)) { group = value } } label: {
            Text(title).font(.system(size: 12, weight: group == value ? .medium : .regular)).padding(.horizontal, 17).padding(.vertical, 10).background(group == value ? Color.ink : Color.surface, in: Capsule()).foregroundStyle(group == value ? Color.inverse : Color.muted)
        }.accessibilityIdentifier("sphere.filter.\(title)")
    }
}

struct PersonRow: View {
    let person: Person
    let events: [LifeEvent]
    var body: some View {
        HStack(spacing: 15) {
            PersonAvatar(person: person)
            VStack(alignment: .leading, spacing: 6) { Text(person.name).font(.system(size: 15, weight: .medium)); Text(L("\(person.group.label) · \(events.count) 次记录\(person.isDemo ? L(" · 示例") : "")")).font(.system(size: 11)).foregroundStyle(Color.muted) }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(Color.muted)
        }.padding(.vertical, 6).contentShape(Rectangle())
    }
}

struct PersonDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let personID: UUID
    @State private var editing = false
    @State private var review = false
    @State private var deleting = false
    var body: some View {
        ScrollView {
            if let person = store.person(personID) {
                let events = store.events(for: person)
                VStack(alignment: .leading, spacing: 26) {
                    HStack(spacing: 20) {
                        PersonAvatar(person: person, size: 82)
                        VStack(alignment: .leading, spacing: 12) { Text(person.name).font(.system(size: 32, weight: .medium)); HStack { Tag(text: person.group.label); if person.isDemo { Tag(text: L("示例人物")) } } }
                    }.padding(.top, 10)
                    if let organization = person.organization, !organization.isEmpty { Label(organization, systemImage: "building.2").font(.subheadline).foregroundStyle(Color.muted) }
                    PersonProfileDetails(person: person)
                    if !person.note.isEmpty { Text(person.note).font(.system(size: 16)).foregroundStyle(Color.muted).lineSpacing(6) }
                    HStack(spacing: 0) {
                        metric(L("共同记录"), value: "\(events.count)")
                        metric(L("首次记录"), value: events.last?.date.formatted(.dateTime.locale(AppPreferences.shared.locale).month().day()) ?? "—")
                        metric(L("最近互动"), value: events.first?.date.formatted(.dateTime.locale(AppPreferences.shared.locale).month().day()) ?? "—")
                    }.padding(.vertical, 20)
                    Button { review = true } label: { HStack { Image(systemName: "waveform.path"); Text(L("聊聊与\(person.name)的经历")) } }.buttonStyle(PrimaryButtonStyle())
                    Divider()
                    SectionHeading(title: L("互动中的感受"), subtitle: L("你的经历"))
                    if events.isEmpty { Text(L("还没有记录。一次真实的互动，就是了解这段关系的起点。")) .font(.subheadline).foregroundStyle(Color.muted) }
                    HStack { ForEach(Emotion.allCases.filter { feeling in events.contains { $0.feeling == feeling } }) { feeling in Tag(text: "\(feeling.label) \(events.filter { $0.feeling == feeling }.count)", color: feeling.color) } }
                    Notice(text: L("感受来自你的单方记录，仅反映当时的体验，不用于判断对方的人格或关系好坏。"))
                    if !events.isEmpty { AIAnalysisCard(context: events.prefix(10).map(\.analysisText).joined(separator: "\n\n"), purpose: "person") }
                    SectionHeading(title: L("我们之间的片段"))
                    ForEach(events) { event in NavigationLink { EventDetailView(eventID: event.id) } label: { EventRow(event: event) }.buttonStyle(.plain) }
                    if !person.isDemo { Button(L("移除此人物"), role: .destructive) { deleting = true }.font(.caption).frame(maxWidth: .infinity).padding(.top, 20) }
                }.padding(25).frame(maxWidth: 680).frame(maxWidth: .infinity)
            } else { EmptySpace(icon: "person", title: L("人物已移除"), message: L("相关事件仍保留在历史记录中。")) }
        }.pageStyle().navigationTitle(L("关系档案")).navigationBarTitleDisplayMode(.inline)
            .toolbar { if let person = store.person(personID), !person.isDemo { Button(L("编辑")) { editing = true }.accessibilityIdentifier("person.edit") } }
            .sheet(isPresented: $editing) { PersonEditor(existing: store.person(personID)) }
            .sheet(isPresented: $review) { ReviewView(personID: personID) }
            .confirmationDialog(L("移除人物会解除事件关联，保留事件内容。"), isPresented: $deleting, titleVisibility: .visible) { Button(L("移除人物"), role: .destructive) { store.deletePerson(personID); dismiss() } }
    }
    private func metric(_ title: String, value: String) -> some View { VStack(spacing: 9) { Text(value).font(.system(size: 22, weight: .light)); Text(title).font(.system(size: 10)).foregroundStyle(Color.muted) }.frame(maxWidth: .infinity) }
}

struct RelationshipInsightsView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                PageHeading(eyebrow: L("互动中的线索"), title: L("在互动里，发现线索。"), subtitle: L("以下仅统计已关联的记录，未记录的互动不会被计算。"))
                if store.people.isEmpty { EmptySpace(icon: "point.3.connected.trianglepath.dotted", title: L("理解需要真实的经历"), message: L("添加人物并关联事件后，会看到互动中的线索。")) }
                ForEach(store.people) { person in
                    let events = store.events(for: person)
                    NavigationLink { PersonDetailView(personID: person.id) } label: {
                        VStack(alignment: .leading, spacing: 17) {
                            HStack { Text(person.name).font(.headline); Tag(text: person.group.label); Spacer(); Text(L("\(events.count) 次")).font(.system(size: 13, design: .monospaced)) }
                            GeometryReader { geometry in
                                HStack(spacing: 3) {
                                    ForEach(Emotion.allCases) { feeling in
                                        let count = events.filter { $0.feeling == feeling }.count
                                        if count > 0 { RoundedRectangle(cornerRadius: 2).fill(feeling.color.opacity(0.65)).frame(width: max(0, (geometry.size.width - 15) * Double(count) / Double(max(events.count, 1)))) }
                                    }
                                }
                            }.frame(height: 5)
                            Text(events.isEmpty ? L("还没有相关经历") : L("记录的感受：") + Emotion.allCases.filter { feeling in events.contains { $0.feeling == feeling } }.map { feeling in L("\(feeling.label) \(events.filter { $0.feeling == feeling }.count) 次") }.joined(separator: " · ")) .font(.system(size: 11)).foregroundStyle(Color.muted)
                            HStack { Text(person.isDemo ? L("示例数据 · 点击查看具体记录") : L("来源：你确认关联的事件")); Spacer(); Image(systemName: "arrow.up.right") }.font(.caption2).foregroundStyle(Color.muted)
                        }.surface()
                    }.buttonStyle(.plain)
                }
                Notice(text: L("互惠、支持与消耗需要你明确描述后才能讨论。这里不生成关系评分，也不替你作关系决定。"))
            }.padding(25)
        }.pageStyle().navigationTitle(L("关系洞察")).navigationBarTitleDisplayMode(.inline)
    }
}

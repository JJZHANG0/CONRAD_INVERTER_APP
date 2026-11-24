import SwiftUI

struct HistoryView: View {
    @Environment(AppStore.self) private var store
    var favoritesOnly = false
    @State private var search = ""
    @State private var review = false
    private var filtered: [LifeEvent] {
        store.events.filter { (!favoritesOnly || $0.isFavorite) && (search.isEmpty || "\($0.title)\($0.facts)\($0.need)".localizedCaseInsensitiveContains(search)) }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if filtered.isEmpty {
                    EmptySpace(icon: favoritesOnly ? "bookmark" : "text.book.closed", title: favoritesOnly ? L("值得再看一遍的经历") : L("让经历留下线索"), message: search.isEmpty ? L("从一次真实的记录开始，慢慢积累属于你的理解。") : L("没有找到相关记录，试试其他关键词。"))
                }
                ForEach(filtered) { event in
                    NavigationLink { EventDetailView(eventID: event.id) } label: { EventRow(event: event) }.buttonStyle(.plain)
                    Divider()
                }
            }.padding(24).frame(maxWidth: 720).frame(maxWidth: .infinity)
        }.pageStyle().navigationTitle(favoritesOnly ? L("我的收藏") : L("历史记录")).navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: L("搜索经历、感受或在意点"))
            .toolbar { if !favoritesOnly { Button { review = true } label: { Image(systemName: "plus") }.accessibilityLabel(L("新建记录")) } }
            .sheet(isPresented: $review) { ReviewView() }
    }
}

struct EventDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let eventID: UUID
    @State private var editing = false
    @State private var deleting = false
    @State private var review = false
    var body: some View {
        ScrollView {
            if let event = store.event(eventID) {
                VStack(alignment: .leading, spacing: 25) {
                    Eyebrow(text: L("一个理解的片刻"))
                    Text(event.title).font(.system(size: 29, weight: .medium))
                    HStack { Tag(text: event.feeling.label, color: event.feeling.color); Text(event.date.formatted(.dateTime.locale(AppPreferences.shared.locale).year().month().day())).font(.caption).foregroundStyle(Color.muted); if event.isDemo { Tag(text: L("示例记录")) } }
                    if let imageData = event.imageData, let image = UIImage(data: imageData) { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 260).clipShape(RoundedRectangle(cornerRadius: 14)) }
                    detail("01", title: L("发生了什么"), value: event.facts)
                    detail("02", title: L("我的解释"), value: event.interpretation.isEmpty ? L("还没有写下解释。") : event.interpretation)
                    detail("03", title: L("我在意的"), value: event.need.isEmpty ? L("仍在探索。") : event.need)
                    detail("04", title: L("仍然未知"), value: event.unknown)
                    detail("05", title: L("下一小步"), value: event.nextStep.isEmpty ? L("暂时不行动，也是一种选择。") : event.nextStep)
                    if !event.personIDs.isEmpty {
                        SectionHeading(title: L("这次经历中的人"))
                        ForEach(event.personIDs, id: \.self) { id in
                            if let person = store.person(id) { NavigationLink { PersonDetailView(personID: id) } label: { RowLink(icon: "person", title: person.name, detail: person.group.label) } }
                        }
                    }
                    if event.correctedAt != nil { Notice(text: L("这条记录已由你修正。由旧内容生成的记忆已移除。")) }
                    AIAnalysisCard(context: event.analysisText)
                    Button { review = true } label: { Text(L("围绕这件事继续复盘")) }.buttonStyle(PrimaryButtonStyle())
                    if event.isDemo {
                        Notice(text: L("这是帮助你了解功能的示例，不属于你的个人档案。"))
                    } else {
                        Button(L("修正我的记录")) { editing = true }.frame(maxWidth: .infinity).font(.subheadline)
                        Button(L("删除这条记录"), role: .destructive) { deleting = true }.font(.caption).frame(maxWidth: .infinity)
                    }
                }.padding(25).frame(maxWidth: 680).frame(maxWidth: .infinity)
            } else { EmptySpace(icon: "doc", title: L("记录已移除"), message: L("这条记录和关联记忆已不在你的档案中。")) }
        }.pageStyle().navigationTitle(L("事件档案")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let event = store.event(eventID), !event.isDemo {
                    Button { store.toggleFavorite(eventID) } label: { Image(systemName: event.isFavorite ? "bookmark.fill" : "bookmark") }.accessibilityLabel(event.isFavorite ? L("取消收藏") : L("收藏记录"))
                }
            }
            .sheet(isPresented: $editing) { if let event = store.event(eventID) { EventEditor(event: event) } }
            .sheet(isPresented: $review) { ReviewView(sourceEvent: store.event(eventID)) }
            .confirmationDialog(L("删除记录及其关联记忆？此操作无法撤销。"), isPresented: $deleting, titleVisibility: .visible) { Button(L("删除记录"), role: .destructive) { store.deleteEvent(eventID); dismiss() } }
    }
    private func detail(_ number: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) { Text(number).font(.system(size: 10, design: .monospaced)).foregroundStyle(Color.crystal); Text(title).font(.system(size: 13, weight: .semibold)) }
            Text(value).font(.system(size: 16)).lineSpacing(7).fixedSize(horizontal: false, vertical: true)
            Divider().padding(.top, 8)
        }
    }
}

struct EventEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var event: LifeEvent
    var body: some View {
        NavigationStack {
            Form {
                Section(L("事件")) { TextField(L("标题"), text: $event.title); TextField(L("事实"), text: $event.facts, axis: .vertical) }
                Section(L("我的感受和理解")) {
                    Picker(L("情绪"), selection: $event.feeling) { ForEach(Emotion.allCases) { Text($0.label).tag($0) } }
                    TextField(L("我的解释"), text: $event.interpretation, axis: .vertical)
                    TextField(L("我在意的"), text: $event.need, axis: .vertical)
                    TextField(L("仍然未知"), text: $event.unknown, axis: .vertical)
                    TextField(L("下一步"), text: $event.nextStep, axis: .vertical)
                }
                Section { Text(L("修正后将移除旧记录衍生的记忆，并依据新的内容更新洞察。")).font(.caption).foregroundStyle(Color.muted) }
            }.navigationTitle(L("修正理解")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("取消")) { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button(L("保存")) { store.updateEvent(event); dismiss() }.disabled(event.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || event.facts.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } }
        }
    }
}

struct InsightDetailView: View {
    @Environment(AppStore.self) private var store
    let insight: Insight
    var body: some View {
        ScrollView {
            if let insight = store.insights.first(where: { $0.id == insight.id }) {
            VStack(alignment: .leading, spacing: 25) {
                PageHeading(eyebrow: L("连接经历中的线索"), title: L("每个发现，都有来处。"), subtitle: L("从经历中观察线索，为理解保留余地。"))
                Text(insight.title).font(.title2).lineSpacing(6)
                Text(insight.detail).foregroundStyle(Color.muted).lineSpacing(6)
                Notice(text: L("这是一条基于明确记录的线索，不是人格结论。你可以进入原记录修正内容，相关线索会随之更新。"))
                AIAnalysisCard(context: insight.evidenceIDs.compactMap { store.event($0)?.analysisText }.prefix(10).joined(separator: "\n\n"), purpose: "insight")
                SectionHeading(title: L("具体依据"), subtitle: "\(insight.evidenceIDs.count) RECORDS")
                ForEach(insight.evidenceIDs, id: \.self) { id in
                    if let event = store.event(id) { NavigationLink { EventDetailView(eventID: id) } label: { EventRow(event: event) }.buttonStyle(.plain) }
                }
            }.padding(25)
            } else { EmptySpace(icon: "arrow.triangle.2.circlepath", title: L("理解已经更新"), message: L("原记录已被修正、移除或隐藏。这条线索不再沿用，请返回查看最新发现。")) }
        }.pageStyle().navigationTitle(L("认知依据")).navigationBarTitleDisplayMode(.inline)
    }
}

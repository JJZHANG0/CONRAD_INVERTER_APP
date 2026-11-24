import SwiftUI
import UniformTypeIdentifiers

struct GameTile: View {
    let game: DiscoveryGame
    var completed = false
    var body: some View {
        VStack(alignment: .leading, spacing: 19) {
            HStack { Text(game.number).font(.system(size: 10, design: .monospaced)).foregroundStyle(Color.muted); Spacer(); if completed { Image(systemName: "checkmark.circle.fill").font(.system(size: 11)).foregroundStyle(Color.sage) } }
            Image(systemName: game.icon).font(.system(size: 29, weight: .ultraLight)).foregroundStyle(Color.crystal).frame(height: 35)
            VStack(alignment: .leading, spacing: 7) {
                Text(game.title).font(.system(size: 16, weight: .medium)).foregroundStyle(Color.ink)
                Text(game.subtitle).font(.system(size: 10)).foregroundStyle(Color.muted)
            }
            HStack { Text(completed ? L("再次探索") : L("2–5 分钟")); Spacer(); Image(systemName: "arrow.up.right") }.font(.system(size: 10)).foregroundStyle(Color.muted)
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(Color.surface, in: RoundedRectangle(cornerRadius: 17))
    }
}
struct GameCenterView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeading(eyebrow: L("对自己保持一点好奇"), title: L("带着好奇，来玩。"), subtitle: L("没有正确答案，也没有固定的你。每次探索都是一个新的切面。"))
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(DiscoveryGame.all) { game in NavigationLink { GameView(game: game) } label: { GameTile(game: game, completed: store.data.gameResults.contains { $0.gameID == game.id }) }.buttonStyle(.plain) }
                }
                NavigationLink { GameHistoryView() } label: { RowLink(icon: "clock.arrow.circlepath", title: L("过去的探索"), detail: L("\(store.data.gameResults.count) 次")) }
            }.padding(25)
        }.pageStyle().navigationTitle(L("自我探索实验室")).navigationBarTitleDisplayMode(.inline)
    }
}

struct GameView: View {
    @Environment(AppStore.self) private var store
    let game: DiscoveryGame
    @State private var started = false
    @State private var step = 0
    @State private var answers: [String] = []
    @State private var selection = ""
    @State private var custom = ""
    @State private var values = DiscoveryGame.values
    @State private var dragged: String?
    @State private var reflection = ""
    @State private var eventID: UUID?
    @State private var result: GameResult?
    private var isValues: Bool { game.id == "values" }
    private var isReflection: Bool { isValues ? step == 1 : step == game.prompts.count }
    private var currentAnswer: String { custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? selection : custom.trimmingCharacters(in: .whitespacesAndNewlines) }
    var body: some View {
        Group {
            if let result { GameReportView(result: result, embedded: true) }
            else if !started { introduction }
            else { activity }
        }.pageStyle().navigationTitle(game.title).navigationBarTitleDisplayMode(.inline)
    }
    private var introduction: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                HStack { Eyebrow(text: L("自我探索 / \(game.number)")); Spacer(); Tag(text: L("2–5 分钟")) }.padding(.top, 25)
                ZStack {
                    Circle().stroke(Color.line, lineWidth: 0.7).frame(width: 205, height: 205)
                    Circle().stroke(Color.line, style: StrokeStyle(lineWidth: 0.7, dash: [2, 6])).frame(width: 255, height: 255)
                    Image(systemName: game.icon).font(.system(size: 73, weight: .ultraLight)).foregroundStyle(Color.crystal)
                }.frame(maxWidth: .infinity).frame(height: 285)
                Text(game.title).font(.system(size: 35, weight: .medium))
                Text(game.subtitle).font(.system(size: 20)).foregroundStyle(Color.muted)
                Text(isValues ? L("把这些价值从「此刻最重要」开始排列。没有正确的顺序，未来的你也可以有不同答案。") : L("把自己放进一个具体情境，选择最接近此刻的答案。也可以写下自己的回应。")) .font(.system(size: 15)).foregroundStyle(Color.muted).lineSpacing(7)
                Button { withAnimation { started = true } } label: { HStack { Text(L("开始探索")); Image(systemName: "arrow.right") } }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("game.start")
                Notice(text: L("这是自我反思练习，不是临床诊断或标准化测评。结果只代表本次探索。"))
            }.padding(25).frame(maxWidth: 680).frame(maxWidth: .infinity)
        }
    }
    private var activity: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ProgressView(value: Double(step), total: Double(isValues ? 2 : game.prompts.count + 1)).tint(.ink).padding(.top, 20)
                Eyebrow(text: isReflection ? L("停下来，想一想") : L("探索 / 0\(step + 1)"))
                if isReflection { reflectionStep }
                else if isValues { rankingStep }
                else { questionStep }
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    if isReflection {
                        let finalAnswers = isValues ? values : answers
                        let report = GameResult(gameID: game.id, answers: finalAnswers, reflection: reflection.trimmingCharacters(in: .whitespacesAndNewlines), eventID: eventID)
                        if store.saveGame(report) { result = report }
                    } else {
                        if !isValues { if answers.count > step { answers[step] = currentAnswer } else { answers.append(currentAnswer) } }
                        withAnimation { step += 1; selection = ""; custom = "" }
                    }
                } label: { Text(isReflection ? L("保存我的探索报告") : isValues ? L("看看这次的排序") : L("下一步")) }.buttonStyle(PrimaryButtonStyle()).disabled(!isValues && !isReflection && currentAnswer.isEmpty).opacity(!isValues && !isReflection && currentAnswer.isEmpty ? 0.45 : 1).accessibilityIdentifier("game.next")
                if step > 0 { Button(L("返回修改")) { step -= 1; if !isValues { selection = answers[step] }; custom = "" }.font(.subheadline).frame(maxWidth: .infinity) }
            }.padding(25).frame(maxWidth: 680).frame(maxWidth: .infinity)
        }.scrollDismissesKeyboard(.interactively)
    }
    private var rankingStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L("此刻，什么更重要？")).font(.system(size: 27, weight: .medium))
            Text(L("长按拖动排序，也可使用箭头调整。")) .font(.system(size: 12)).foregroundStyle(Color.muted)
            ForEach(Array(values.enumerated()), id: \.element) { index, value in
                HStack(spacing: 15) {
                    Text(String(format: "%02d", index + 1)).font(.system(size: 11, design: .monospaced)).foregroundStyle(index == 0 ? Color.crystal : Color.muted)
                    Text(value).font(.system(size: 17, weight: index < 3 ? .medium : .regular))
                    Spacer()
                    Button { if index > 0 { values.swapAt(index, index - 1) } } label: { Image(systemName: "chevron.up").frame(width: 30, height: 32) }.disabled(index == 0).accessibilityLabel(L("上移\(value)"))
                    Button { if index < values.count - 1 { values.swapAt(index, index + 1) } } label: { Image(systemName: "chevron.down").frame(width: 30, height: 32) }.disabled(index == values.count - 1).accessibilityLabel(L("下移\(value)"))
                    Image(systemName: "line.3.horizontal").foregroundStyle(Color.muted)
                }.font(.system(size: 12)).padding(.horizontal, 15).padding(.vertical, 8).background(Color.surface, in: RoundedRectangle(cornerRadius: 12))
                    .onDrag { dragged = value; return NSItemProvider(object: value as NSString) }
                    .onDrop(of: [.text], delegate: ValueDropDelegate(item: value, values: $values, dragged: $dragged))
            }
        }
    }
    private var questionStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(game.prompts[step].question).font(.system(size: 26, weight: .medium)).lineSpacing(8).padding(.bottom, 10)
            ForEach(Array(game.prompts[step].options.enumerated()), id: \.offset) { index, option in
                Button { selection = option; custom = "" } label: {
                    HStack(alignment: .center, spacing: 15) {
                        Text(String(UnicodeScalar(65 + index)!)).font(.system(size: 11, design: .monospaced)).foregroundStyle(Color.muted)
                        Text(option).font(.system(size: 15)).multilineTextAlignment(.leading).lineSpacing(4)
                        Spacer(minLength: 2)
                        Image(systemName: selection == option && custom.isEmpty ? "checkmark.circle.fill" : "circle").foregroundStyle(selection == option && custom.isEmpty ? Color.crystal : Color.line)
                    }.padding(18).background(Color.surface, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(selection == option && custom.isEmpty ? Color.crystal : .clear, lineWidth: 1))
                }.buttonStyle(.plain).accessibilityIdentifier("game.option.\(index)")
            }
            TextField(L("或者，写下你自己的回答"), text: $custom, axis: .vertical).lineLimit(2...4).font(.subheadline).padding(17).background(Color.surface, in: RoundedRectangle(cornerRadius: 14))
        }
    }
    private var reflectionStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(L("把选择，放回生活里。")).font(.system(size: 27, weight: .medium))
            if isValues {
                HStack { ForEach(Array(values.prefix(3).enumerated()), id: \.offset) { index, value in Tag(text: "\(index + 1) · \(value)") } }
            }
            Text(game.reflectionPrompt).font(.system(size: 17)).lineSpacing(7)
            TextField(L("写下一次经历或一个发现（可选）"), text: $reflection, axis: .vertical).lineLimit(5...8).padding(17).background(Color.surface, in: RoundedRectangle(cornerRadius: 14))
            Picker(L("关联一次真实记录"), selection: $eventID) { Text(L("暂不关联")).tag(nil as UUID?); ForEach(store.data.events) { Text($0.title).tag(Optional($0.id)) } }.font(.subheadline)
            Notice(text: L("报告会保存在本机游戏记录中。只有开启「游戏探索记忆」后，才会加入长期记忆。"))
        }
    }
}

struct ValueDropDelegate: DropDelegate {
    let item: String
    @Binding var values: [String]
    @Binding var dragged: String?
    func dropEntered(info: DropInfo) {
        guard let dragged, dragged != item, let source = values.firstIndex(of: dragged), let destination = values.firstIndex(of: item) else { return }
        withAnimation(.easeInOut(duration: 0.18)) { values.move(fromOffsets: IndexSet(integer: source), toOffset: destination > source ? destination + 1 : destination) }
    }
    func performDrop(info: DropInfo) -> Bool { dragged = nil; return true }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
}

struct GameReportView: View {
    @Environment(AppStore.self) private var store
    let result: GameResult
    var embedded = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                Eyebrow(text: L("一个切面，不是标签"))
                Text(L("这一刻的你。")).font(.system(size: 33, weight: .medium))
                HStack { Tag(text: DiscoveryGame.title(for: result.gameID)); Text(result.date.formatted(.dateTime.locale(AppPreferences.shared.locale).month().day())).font(.caption).foregroundStyle(Color.muted) }
                Text(result.gameID == "values" ? L("此刻，你把「\(result.answers.prefix(3).joined(separator: "、"))」放在了更前面。") : L("你在这些情境里，留下了属于自己的选择。")) .font(.system(size: 22, weight: .medium)).lineSpacing(8)
                Notice(text: L("这是对本次回答的整理，不是 AI 推断。不同处境下，你可能作出不同选择。"))
                SectionHeading(title: result.gameID == "values" ? L("我的价值排序") : L("我的选择"))
                ForEach(Array(result.answers.enumerated()), id: \.offset) { index, answer in
                    VStack(alignment: .leading, spacing: 10) {
                        if result.gameID != "values", let game = DiscoveryGame.all.first(where: { $0.id == result.gameID }), index < game.prompts.count { Text(game.prompts[index].question).font(.caption).foregroundStyle(Color.muted) }
                        HStack(alignment: .top, spacing: 14) { Text(String(format: "%02d", index + 1)).font(.system(size: 11, design: .monospaced)).foregroundStyle(Color.crystal); Text(answer).font(.system(size: 16)).lineSpacing(5) }
                        Divider().padding(.top, 6)
                    }
                }
                SectionHeading(title: L("我想到的真实经历"))
                Text(result.reflection.isEmpty ? L("这次还没有写下反思。下次探索时，可以带来一个真实的片段。") : result.reflection).font(.system(size: 16)).foregroundStyle(Color.muted).lineSpacing(7)
                if let id = result.eventID, let event = store.event(id) { NavigationLink { EventDetailView(eventID: id) } label: { EventRow(event: event) }.buttonStyle(.plain) }
                AIAnalysisCard(context: L("自我探索练习：\(DiscoveryGame.title(for: result.gameID))\n本次选择：\(result.answers.joined(separator: "; "))\n真实经历与反思：\(result.reflection)"), purpose: "game")
                if !embedded, let game = DiscoveryGame.all.first(where: { $0.id == result.gameID }) { NavigationLink { GameView(game: game) } label: { Text(L("再探索一次")) }.buttonStyle(PrimaryButtonStyle()) }
                if embedded { Text(L("已保存 · 可以从「我的 → 游戏记录」再次查看")) .font(.caption).foregroundStyle(Color.sage) }
            }.padding(25).frame(maxWidth: 680).frame(maxWidth: .infinity)
        }.pageStyle().navigationTitle(L("探索报告")).navigationBarTitleDisplayMode(.inline)
    }
}
struct GameHistoryView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        List {
            if store.data.gameResults.isEmpty { EmptySpace(icon: "sparkles", title: L("保持一点好奇"), message: L("完成一次探索后，报告会保存在这里。")) }
            ForEach(store.data.gameResults) { result in NavigationLink { GameReportView(result: result) } label: { VStack(alignment: .leading, spacing: 7) { Text(DiscoveryGame.title(for: result.gameID)); Text(result.date.formatted(.dateTime.locale(AppPreferences.shared.locale).month().day().hour().minute())).font(.caption).foregroundStyle(Color.muted) }.padding(.vertical, 8) } }
                .onDelete { indexes in let ids = indexes.map { store.data.gameResults[$0].id }; ids.forEach { store.deleteGame($0) } }
        }.navigationTitle(L("游戏记录")).navigationBarTitleDisplayMode(.inline)
    }
}

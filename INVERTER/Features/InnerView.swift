import SwiftUI
import Charts

struct InnerView: View {
    @Environment(AppStore.self) private var store
    @State private var review = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 31) {
                PageHeading(eyebrow: L("内在世界"), title: L("向内，遇见自己。"), subtitle: L("你不是一个固定的答案，而是持续发生的变化。"))
                NavigationLink { PortraitView() } label: {
                    VStack(alignment: .leading, spacing: 17) {
                        HStack { Eyebrow(text: L("认知画像")); Spacer(); Image(systemName: "arrow.up.right").font(.caption) }
                        HStack(spacing: 8) {
                            ZStack {
                                OrbitArtwork().frame(width: 128, height: 150)
                                Circle().fill(Color.surface.opacity(0.85)).frame(width: 55, height: 55)
                                Text(L("我")).font(.system(size: 21, weight: .light))
                            }
                            VStack(alignment: .leading, spacing: 12) {
                                Text(L("每一个你，\n都值得被看见。")) .font(.system(size: 20, weight: .medium)).lineSpacing(6).lineLimit(nil).fixedSize(horizontal: false, vertical: true)
                                Text(L("\(store.events.count) 段经历 · \(store.insights.count) 条线索")) .font(.system(size: 11)).foregroundStyle(Color.muted)
                                Tag(text: L("正在形成的认知画像"))
                            }
                        }
                        Text(L("不定义你，只帮你看见自己的线索。")) .font(.system(size: 11)).foregroundStyle(Color.muted)
                    }.surface()
                }.buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 20) {
                    HStack { SectionHeading(title: L("情绪的流动")); NavigationLink { EmotionMapView() } label: { Image(systemName: "arrow.up.right").font(.system(size: 13)) } }
                    EmotionChart(events: Array(store.events.prefix(7)))
                    Text(L("每一种感受，都有它的来处。")) .font(.system(size: 11)).foregroundStyle(Color.muted)
                }
                Divider()
                VStack(alignment: .leading, spacing: 20) {
                    HStack { SectionHeading(title: L("换个方式，认识自己")); NavigationLink { GameCenterView() } label: { Image(systemName: "arrow.up.right").font(.system(size: 13)) } }
                    Text(L("六场轻盈的探索，没有标准答案。")) .font(.system(size: 12)).foregroundStyle(Color.muted)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 13) {
                        ForEach(DiscoveryGame.all) { game in
                            NavigationLink { GameView(game: game) } label: { GameTile(game: game, completed: store.data.gameResults.contains { $0.gameID == game.id }) }.buttonStyle(.plain)
                        }
                    }
                }
                NavigationLink { GrowthView() } label: { RowLink(icon: "point.topleft.down.to.point.bottomright.curvepath", title: L("我的成长轨迹"), detail: L("每一步，都算数")) }
                Button { review = true } label: { HStack { Image(systemName: "waveform.path"); Text(L("开始一次深度复盘")); Spacer(); Image(systemName: "arrow.right") } }.buttonStyle(PrimaryButtonStyle())
            }.padding(25).padding(.top, 12).padding(.bottom, 15).frame(maxWidth: 720).frame(maxWidth: .infinity)
        }.pageStyle().toolbar(.hidden, for: .navigationBar).sheet(isPresented: $review) { ReviewView() }
    }
}

struct EmotionChart: View {
    let events: [LifeEvent]
    var body: some View {
        if events.isEmpty {
            EmptySpace(icon: "water.waves", title: L("感受还没有留下足迹"), message: L("完成一次复盘后，你记录的情绪会出现在这里。"))
        } else {
            Chart(events.sorted { $0.date < $1.date }) { event in
                PointMark(x: .value(L("日期"), event.date), y: .value(L("感受"), event.feeling.label))
                    .foregroundStyle(event.feeling.color).symbolSize(60)
                    .accessibilityLabel("\(event.date.formatted(.dateTime.locale(AppPreferences.shared.locale).month().day()))，\(event.feeling.label)")
            }
            .chartYScale(domain: Emotion.allCases.map(\.label).reversed())
            .chartXAxis { AxisMarks(values: .stride(by: .day)) { _ in AxisValueLabel(format: .dateTime.day(), centered: true).foregroundStyle(Color.muted) } }
            .chartYAxis { AxisMarks(position: .leading, values: Emotion.allCases.map(\.label)) { value in AxisGridLine(centered: true, stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 4])).foregroundStyle(Color.line); AxisValueLabel(centered: true) { if let feeling = value.as(String.self) { Text(feeling).font(.system(size: 10)).foregroundStyle(Color.muted) } } } }
            .frame(height: 180)
        }
    }
}

struct EmotionMapView: View {
    @Environment(AppStore.self) private var store
    @State private var filter: Emotion?
    @State private var review = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                PageHeading(eyebrow: L("情绪地图"), title: L("听见自己的感受。"), subtitle: L("这里展示你主动记录的情绪，不对它们打分。"))
                EmotionChart(events: store.events)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack { Button { filter = nil } label: { Tag(text: L("全部"), color: filter == nil ? .ink : .muted) }; ForEach(Emotion.allCases) { emotion in Button { filter = emotion } label: { Tag(text: emotion.label, color: filter == emotion ? .ink : .muted) } } }
                }
                ForEach(store.events.filter { filter == nil || $0.feeling == filter }) { event in
                    NavigationLink { EventDetailView(eventID: event.id) } label: { EventRow(event: event) }.buttonStyle(.plain)
                }
                if store.events.filter({ filter == nil || $0.feeling == filter }).isEmpty { EmptySpace(icon: "leaf", title: L("这里暂时没有记录"), message: L("留意下次这种感受出现时，发生了什么。")) }
                Button { review = true } label: { Text(L("记下此刻的感受")) }.buttonStyle(PrimaryButtonStyle())
            }.padding(25)
        }.pageStyle().navigationTitle(L("我的情绪地图")).navigationBarTitleDisplayMode(.inline).sheet(isPresented: $review) { ReviewView() }
    }
}

struct PortraitView: View {
    @Environment(AppStore.self) private var store
    private let dimensions = [(L("情绪特征"), "water.waves", L("留意感受，和它出现的情境。")), (L("价值与在意点"), "diamond", L("你在经历中反复提及的期待。")), (L("思维与解释"), "circle.hexagongrid", L("把自己的解释与事实分开看。")), (L("行为倾向"), "arrow.triangle.branch", L("回顾你在具体情境中的选择。")), (L("个人优势"), "sparkle", L("从真实的成功经历中找线索。")), (L("成长方向"), "arrow.up.right", L("由你决定下一步想尝试什么。"))]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                PageHeading(eyebrow: L("持续变化的自己"), title: L("正在形成的你。"), subtitle: L("画像来自记录，随你的修正而改变。"))
                if !store.data.events.isEmpty { AIAnalysisCard(context: store.data.events.prefix(10).map(\.analysisText).joined(separator: "\n\n"), purpose: "portrait") }
                OrbitArtwork().frame(height: 200).frame(maxWidth: .infinity)
                ForEach(Array(dimensions.enumerated()), id: \.offset) { index, dimension in
                    NavigationLink {
                        PortraitDimensionView(index: index, title: dimension.0, subtitle: dimension.2)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            RowLink(icon: dimension.1, title: dimension.0, detail: L("查看依据"))
                            Text(dimension.2).font(.caption).foregroundStyle(Color.muted).padding(.leading, 43)
                        }.padding(.bottom, 12)
                    }
                    Divider()
                }
                Notice(text: L("这不是经过标准化验证的人格测评。没有记录支持时，不生成确定性判断。"))
            }.padding(25)
        }.pageStyle().navigationTitle(L("认知画像")).navigationBarTitleDisplayMode(.inline)
    }
}
struct PortraitDimensionView: View {
    @Environment(AppStore.self) private var store
    let index: Int
    let title: String
    let subtitle: String
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeading(eyebrow: L("先看依据，再谈理解"), title: title, subtitle: subtitle)
                if index == 1 && !store.insights.isEmpty {
                    ForEach(store.insights) { insight in NavigationLink { InsightDetailView(insight: insight) } label: { VStack(alignment: .leading, spacing: 9) { Text(insight.title).font(.headline); Text(L("\(insight.evidenceIDs.count) 次记录 · 查看依据")).font(.caption).foregroundStyle(Color.muted) }.surface() }.buttonStyle(.plain) }
                }
                if store.events.isEmpty { EmptySpace(icon: "circle.dotted", title: L("留一点时间，慢慢了解"), message: L("记录具体经历后，再来观察其中的线索。")) }
                ForEach(store.events) { event in
                    NavigationLink { EventDetailView(eventID: event.id) } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(excerpt(event)).font(.system(size: 17)).lineSpacing(5).foregroundStyle(Color.ink)
                            Text(L("来自：\(event.title)\(event.isDemo ? L(" · 示例") : "")")).font(.caption).foregroundStyle(Color.muted)
                        }.frame(maxWidth: .infinity, alignment: .leading).surface()
                    }.buttonStyle(.plain)
                }
                if index == 4 { NavigationLink { GameView(game: DiscoveryGame.all[5]) } label: { Text(L("通过真实经历探索优势")) }.buttonStyle(PrimaryButtonStyle()) }
            }.padding(25)
        }.pageStyle().navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
    private func excerpt(_ event: LifeEvent) -> String {
        switch index { case 0: L("那时，我感到\(event.feeling.label)。"); case 1: event.need.isEmpty ? L("还在寻找在意的事。") : event.need; case 2: event.interpretation.isEmpty ? L("尚未记录解释。") : event.interpretation; case 3: event.facts; case 4: L("从「\(event.title)」回看：你做了什么，让事情发生了变化？"); default: event.nextStep.isEmpty ? L("还没有计划下一步。") : event.nextStep }
    }
}

struct GrowthView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                PageHeading(eyebrow: L("小步前行，真实改变"), title: L("变化，正在发生。"), subtitle: L("这里没有成长分数，只有你留下的足迹。"))
                if store.data.events.isEmpty && store.data.gameResults.isEmpty { EmptySpace(icon: "point.topleft.down.to.point.bottomright.curvepath", title: L("这是你的起点"), message: L("真实记录和游戏探索会在这里汇成时间线。示例数据不会计入成长。")) }
                ForEach(store.data.gameResults) { result in
                    NavigationLink { GameReportView(result: result) } label: { RowLink(icon: "sparkle", title: L("完成「\(DiscoveryGame.title(for: result.gameID))」"), detail: result.date.formatted(.dateTime.locale(AppPreferences.shared.locale).month().day())) }
                }
                ForEach(store.data.events) { event in
                    NavigationLink { EventDetailView(eventID: event.id) } label: {
                        HStack(alignment: .top, spacing: 17) {
                            VStack { Circle().fill(Color.crystal).frame(width: 7, height: 7); Rectangle().fill(Color.line).frame(width: 1, height: 70) }
                            VStack(alignment: .leading, spacing: 10) {
                                Eyebrow(text: (event.correctedAt ?? event.date).formatted(.dateTime.month().day()))
                                Text(event.correctedAt == nil ? L("留下一段真实经历") : L("修正了过去的理解")).font(.headline)
                                Text(event.title).font(.subheadline).foregroundStyle(Color.muted)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.buttonStyle(.plain)
                }
            }.padding(25)
        }.pageStyle().navigationTitle(L("成长轨迹")).navigationBarTitleDisplayMode(.inline)
    }
}

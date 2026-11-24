import SwiftUI

struct HomeView: View {
    @Environment(AppStore.self) private var store
    @Binding var tab: AppTab
    @State private var review = false
    @State private var chat = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.arrow.down").font(.system(size: 17, weight: .bold))
                        Text("INVERTER").font(.system(size: 17, weight: .bold)).tracking(3)
                    }
                    Spacer()
                    Button { tab = .profile } label: {
                        Text(String(store.data.profile.name.prefix(1))).font(.system(size: 12, weight: .medium))
                            .frame(width: 37, height: 37).background(Color.surface, in: Circle()).overlay(Circle().stroke(Color.line, lineWidth: 1))
                    }.accessibilityLabel(L("个人资料"))
                }
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Eyebrow(text: Date().formatted(.dateTime.locale(AppPreferences.shared.locale).month(.twoDigits).day(.twoDigits).weekday(.wide)).uppercased())
                        Spacer()
                        HStack(spacing: 5) { Circle().fill(Color.sage).frame(width: 5, height: 5); Text(L("你的认知空间")) }.font(.system(size: 10)).foregroundStyle(Color.muted)
                    }
                    Text(L("慢慢理解，\n每一个自己。"))
                        .font(.system(size: 36, weight: .medium)).tracking(1).lineSpacing(7).padding(.top, 8)
                    HStack(alignment: .center, spacing: 0) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(L("理解他人。\n也理解自己。"))
                                .font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.1).lineSpacing(6).foregroundStyle(Color.muted)
                            Text(L("今天，什么让你更了解自己？"))
                                .font(.system(size: 12)).foregroundStyle(Color.muted)
                        }
                        Spacer(minLength: 0)
                        Button { chat = true } label: {
                            ZStack { Color.paper; BotAvatar() }.frame(width: 142, height: 142).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityLabel(L("和我聊聊")).accessibilityIdentifier("home.bot")
                    }.padding(.top, 0)
                }
                Button { review = true } label: {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack {
                            HStack(spacing: 7) { Image(systemName: "waveform.path"); Text(L("留一个片刻，给自己")) }.font(.system(size: 12, weight: .medium))
                            Spacer()
                            Text(L("复盘")).font(.system(size: 9, design: .monospaced)).tracking(1.4).opacity(0.55)
                        }
                        Text(L("今天发生了什么？\n不需要组织语言。"))
                            .font(.system(size: 22, weight: .medium)).lineSpacing(7).multilineTextAlignment(.leading)
                        HStack(spacing: 18) {
                            Image(systemName: "mic"); Image(systemName: "photo")
                            Text(L("文字 · 语音 · 图片")).font(.system(size: 10)).opacity(0.55)
                            Spacer()
                            Image(systemName: "arrow.up.right").font(.system(size: 17)).frame(width: 34, height: 34).background(Color.surface.opacity(0.12), in: Circle())
                        }.font(.system(size: 17, weight: .light))
                    }.padding(23).foregroundStyle(.white).background(Color.hero, in: RoundedRectangle(cornerRadius: 21))
                }.buttonStyle(.plain).accessibilityIdentifier("home.review")
                VStack(alignment: .leading, spacing: 17) {
                    SectionHeading(title: L("今日认知"), subtitle: L("今日线索"))
                    if let insight = store.insights.first {
                        NavigationLink { InsightDetailView(insight: insight) } label: {
                            HStack(alignment: .top, spacing: 14) {
                                Rectangle().fill(Color.crystal).frame(width: 2)
                                VStack(alignment: .leading, spacing: 13) {
                                    Text(insight.title).font(.system(size: 18, weight: .medium)).lineSpacing(6).foregroundStyle(Color.ink)
                                    HStack { Text(L("来源：\(insight.evidenceIDs.count) 次相关记录\(insight.isDemo ? L(" · 示例") : "")")); Spacer(); Image(systemName: "arrow.up.right") }.font(.system(size: 11)).foregroundStyle(Color.muted)
                                }
                            }.fixedSize(horizontal: false, vertical: true)
                        }.buttonStyle(.plain)
                    } else {
                        Text(L("认知，从真实的经历开始。")) .font(.system(size: 18, weight: .medium))
                        Text(L("记录中的共同线索足够清晰时，会在这里呈现。")) .font(.system(size: 12)).foregroundStyle(Color.muted)
                    }
                }
                Divider().overlay(Color.line)
                NavigationLink { ChallengeView() } label: {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Eyebrow(text: L("本月挑战"))
                            Spacer()
                            Text(Date().formatted(.dateTime.locale(AppPreferences.shared.locale).month(.twoDigits)) + " / " + Date().formatted(.dateTime.locale(AppPreferences.shared.locale).year())).font(.system(size: 11, design: .monospaced)).foregroundStyle(Color.muted)
                        }
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 9) {
                                Text(store.data.challenge.title).font(.system(size: 23, weight: .medium)).foregroundStyle(Color.ink)
                                Text(store.data.challenge.skipped ? L("本月已暂停，随时可以回来") : L("从一个小小的行动开始。")) .font(.system(size: 12)).foregroundStyle(Color.muted)
                            }
                            Spacer()
                            ZStack {
                                Circle().stroke(Color.line, lineWidth: 3)
                                Circle().trim(from: 0, to: CGFloat(store.data.challenge.completed.count) / 4).stroke(Color.crystal, style: StrokeStyle(lineWidth: 3, lineCap: .round)).rotationEffect(.degrees(-90))
                                Text("\(store.data.challenge.completed.count)/4").font(.system(size: 15, design: .monospaced))
                            }.frame(width: 51, height: 51)
                        }
                        HStack { Text(L("查看本月挑战")); Spacer(); Image(systemName: "arrow.right") }.font(.system(size: 12, weight: .medium)).foregroundStyle(Color.crystal)
                    }.surface()
                }.buttonStyle(.plain)
                HStack(spacing: 0) {
                    quickAction(L("事件复盘"), icon: "text.bubble") { review = true }
                    quickAction(L("探索自我"), icon: "sparkle.magnifyingglass") { tab = .inner }
                    quickAction(L("关系网络"), icon: "point.3.connected.trianglepath.dotted") { tab = .connections }
                }
                if store.data.showDemo {
                    HStack(spacing: 6) { Image(systemName: "circle.dotted"); Text(L("正在展示示例空间，可在「我的」关闭")) }.font(.system(size: 10)).foregroundStyle(Color.muted).frame(maxWidth: .infinity)
                }
            }.padding(.horizontal, 25).padding(.top, 13).padding(.bottom, 28).frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
        }.pageStyle().toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $review) { ReviewView() }
            .fullScreenCover(isPresented: $chat) { CompanionChatView() }
    }
    private func quickAction(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 12) { Image(systemName: icon).font(.system(size: 23, weight: .ultraLight)); Text(title).font(.system(size: 11)) }.frame(maxWidth: .infinity).padding(.vertical, 10)
        }.buttonStyle(.plain)
    }
}

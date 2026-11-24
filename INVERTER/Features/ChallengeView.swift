import SwiftUI

struct ChallengeView: View {
    @Environment(AppStore.self) private var store
    @State private var activeTask: Int?
    @State private var feedback = ""
    @State private var change = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 27) {
                PageHeading(eyebrow: L("每月一点改变"), title: store.data.challenge.title, subtitle: L("成长无需用力过猛。用四个小行动，为自己带来一点新的可能。"))
                HStack(spacing: 25) {
                    ZStack {
                        Circle().stroke(Color.line, lineWidth: 5)
                        Circle().trim(from: 0, to: Double(store.data.challenge.completed.count) / 4).stroke(Color.crystal, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90))
                        VStack(spacing: 3) { Text("\(store.data.challenge.completed.count)").font(.system(size: 35, weight: .light, design: .rounded)); Text(L("共 4 步")).font(.system(size: 9, design: .monospaced)).foregroundStyle(Color.muted) }
                    }.frame(width: 105, height: 105)
                    VStack(alignment: .leading, spacing: 11) { Text(store.data.challenge.completed.count == 4 ? L("给自己的行动，一点肯定。") : store.data.challenge.skipped ? L("给自己一点空间。") : L("跟随自己的节奏。")) .font(.headline); Text(L("不需要连续打卡，也不用和谁比较。")) .font(.caption).foregroundStyle(Color.muted).lineSpacing(5) }
                }.padding(.vertical, 14)
                ForEach(Array(store.data.challenge.tasks.enumerated()), id: \.offset) { index, task in
                    Button {
                        activeTask = index
                        feedback = store.data.challenge.feedback.first { $0.taskID == index }?.text ?? ""
                    } label: {
                        HStack(alignment: .top, spacing: 17) {
                            Image(systemName: store.data.challenge.completed.contains(index) ? "checkmark.circle.fill" : "circle").font(.system(size: 22, weight: .light)).foregroundStyle(store.data.challenge.completed.contains(index) ? Color.sage : Color.muted)
                            VStack(alignment: .leading, spacing: 10) { Eyebrow(text: L("第 0\(index + 1) 步")); Text(task).font(.system(size: 16)); if let response = store.data.challenge.feedback.first(where: { $0.taskID == index }), !response.text.isEmpty { Text(response.text).font(.caption).foregroundStyle(Color.muted).lineLimit(2) } }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.muted)
                        }.padding(.vertical, 14)
                    }.buttonStyle(.plain).disabled(store.data.challenge.skipped)
                    Divider()
                }
                Notice(text: L("选择一个你愿意尝试的方向。每次行动后，留下一点感受，看看什么适合自己。"))
                if !store.data.challenge.feedback.isEmpty { AIAnalysisCard(context: store.data.challenge.title + "\n" + store.data.challenge.feedback.map(\.text).joined(separator: "\n"), purpose: "challenge") }
                Button(L("换一个成长主题")) { change = true }.font(.subheadline).frame(maxWidth: .infinity)
                Button(store.data.challenge.skipped ? L("重新开始本月挑战") : L("这个月，先给自己留白")) { store.data.challenge.skipped.toggle(); store.save() }.font(.caption).foregroundStyle(Color.muted).frame(maxWidth: .infinity)
            }.padding(25).frame(maxWidth: 680).frame(maxWidth: .infinity)
        }.pageStyle().navigationTitle(L("每月成长挑战")).navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(L("更换主题将重置本月进度和反馈。"), isPresented: $change, titleVisibility: .visible) {
                ForEach(Array(Challenge.themes.enumerated()), id: \.offset) { index, title in if index != store.data.challenge.themeIndex { Button(title) { store.data.challenge = Challenge(themeIndex: index); store.save() } } }
            }
            .sheet(isPresented: Binding(get: { activeTask != nil }, set: { if !$0 { activeTask = nil } })) {
                if let index = activeTask {
                    NavigationStack {
                        VStack(alignment: .leading, spacing: 25) {
                            Eyebrow(text: L("给自己的一小步"))
                            Text(store.data.challenge.tasks[index]).font(.system(size: 25, weight: .medium))
                            TextField(L("完成之后，有什么感受？（可选）"), text: $feedback, axis: .vertical).lineLimit(5...8).padding(18).background(Color.surface, in: RoundedRectangle(cornerRadius: 14))
                            Button {
                                if let feedbackIndex = store.data.challenge.feedback.firstIndex(where: { $0.taskID == index }) { store.data.challenge.feedback[feedbackIndex].text = feedback; store.save() }
                                else { store.completeTask(index, feedback: feedback) }
                                activeTask = nil
                            } label: { Text(store.data.challenge.completed.contains(index) ? L("保存感受") : L("完成这一步")) }.buttonStyle(PrimaryButtonStyle())
                            Spacer()
                        }.padding(25).pageStyle().navigationTitle(L("行动与反馈")).navigationBarTitleDisplayMode(.inline).toolbar { Button(L("关闭")) { activeTask = nil } }
                    }.presentationDetents([.medium, .large])
                }
            }
    }
}

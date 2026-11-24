import SwiftUI

struct CompanionChatView: View {
    @Environment(AppStore.self) private var store
    @Environment(CompanionConversation.self) private var conversation
    @Environment(\.dismiss) private var dismiss
    @FocusState private var writing: Bool
    @State private var showAccount = false
    @State private var intent = "start"
    @State private var showCall = false
    @State private var pendingMode: CompanionMode?
    @State private var confirmModeChange = false
    @State private var selectedReport: CompanionReport?
    private var api: CloudService? { try? CloudService(endpoint: store.data.privacy.endpoint.isEmpty ? CloudService.productionURL : store.data.privacy.endpoint) }
    var body: some View {
        @Bindable var conversation = conversation
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: { Image(systemName: "arrow.left").frame(width: 44, height: 44) }.accessibilityLabel(L("返回")).accessibilityIdentifier("chat.close")
                Spacer(); Text("INVERTER").font(.system(size: 12, weight: .medium, design: .monospaced)).tracking(3); Spacer()
                Menu {
                    Button(L("结束并整理")) { perform("finish") }.disabled(conversation.userCount == 0 || conversation.sending || conversation.report != nil)
                    if conversation.report != nil { Button(L("开始新的对话")) { conversation.reset(); perform("start") } }
                    ForEach(store.data.conversationReports ?? []) { report in Button(report.reflection.title) { selectedReport = report } }
                } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }.accessibilityLabel(L("对话选项")).accessibilityIdentifier("chat.menu")
            }.padding(.horizontal, 14)
            modePicker
            if conversation.sending && conversation.lastAction == "finish" {
                ReflectionLoadingView(title: L("把这次理解，留给你。"), detail: L("正在整理你说过的话，和可以带走的一点点改变。")) { conversation.cancel() }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 25) {
                            VStack(spacing: 8) {
                                BotAvatar(state: conversation.sending ? "working" : writing ? "listening" : conversation.report != nil ? "done" : "idle", tint: conversation.mode.color)
                                    .frame(width: conversation.messages.isEmpty ? 250 : 170, height: conversation.messages.isEmpty ? 250 : 170)
                                Text(conversation.stageTitle).font(.caption).foregroundStyle(Color.muted)
                                if conversation.messages.isEmpty && !conversation.sending {
                                    Text(L("我在，慢慢说。")) .font(.system(size: 27, weight: .medium)).padding(.top, 8)
                                    Button(L("开始聊聊")) { perform("start") }.padding(.top, 12).accessibilityIdentifier("chat.start")
                                }
                            }.frame(maxWidth: .infinity).padding(.top, 20)
                            ForEach(conversation.messages) { message in
                                HStack {
                                    if message.role == "user" { Spacer(minLength: 42) }
                                    Text(message.content).font(.system(size: 17)).lineSpacing(6).textSelection(.enabled)
                                        .padding(message.role == "user" ? 16 : 0)
                                        .background(message.role == "user" ? Color.surface : .clear, in: RoundedRectangle(cornerRadius: 22))
                                        .accessibilityIdentifier(message.role == "user" ? "chat.user" : "chat.reply")
                                    if message.role == "assistant" { Spacer(minLength: 20) }
                                }
                            }
                            if conversation.sending { ProgressView(L("正在听，也在想…")).font(.caption).accessibilityIdentifier("chat.waiting") }
                            if let failure = conversation.failure {
                                VStack(spacing: 12) { Text(failure).font(.caption).foregroundStyle(Color.muted); Button(L("再试一次")) { perform("retry") }.accessibilityIdentifier("chat.retry") }
                            }
                            if let report = conversation.report {
                                Button { selectedReport = report } label: { HStack { VStack(alignment: .leading, spacing: 7) { Text(L("这次对话，留给你")).font(.caption); Text(report.reflection.title).font(.title3) }; Spacer(); Image(systemName: "arrow.up.right") }.padding(20).background(Color.surface, in: RoundedRectangle(cornerRadius: 20)) }.buttonStyle(.plain).accessibilityIdentifier("chat.report")
                                Button(L("开始新的对话")) { conversation.reset(); perform("start") }.font(.subheadline)
                            }
                            Color.clear.frame(height: 1).id("chat.bottom")
                        }.padding(.horizontal, 26).padding(.bottom, 16).frame(maxWidth: 640).frame(maxWidth: .infinity)
                    }.scrollDismissesKeyboard(.interactively)
                        .onChange(of: conversation.messages.count) { _, _ in withAnimation { proxy.scrollTo("chat.bottom", anchor: .bottom) } }
                        .onChange(of: conversation.failure) { _, _ in withAnimation { proxy.scrollTo("chat.bottom", anchor: .bottom) } }
                }
            }
        }.background(Color.paper.ignoresSafeArea()).foregroundStyle(Color.ink)
            .safeAreaInset(edge: .bottom) {
                if conversation.report == nil {
                    VStack(spacing: 7) {
                        HStack(alignment: .bottom, spacing: 10) {
                            Button { perform("voice") } label: { Image(systemName: "waveform").font(.system(size: 22)).frame(width: 38, height: 40) }.accessibilityLabel(L("语音对话")).accessibilityIdentifier("chat.voice")
                            TextField(L("想说什么都可以…"), text: $conversation.draft, axis: .vertical).lineLimit(1...5).font(.system(size: 16)).focused($writing).accessibilityIdentifier("chat.input")
                            Button { perform("send") } label: { Image(systemName: "arrow.up").font(.system(size: 17, weight: .semibold)).foregroundStyle(Color.paper).frame(width: 40, height: 40).background(Color.ink, in: Circle()) }
                                .disabled(conversation.sending || conversation.needsReply || conversation.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || conversation.draft.count > 4000)
                                .accessibilityLabel(L("发送")).accessibilityIdentifier("chat.send")
                        }.padding(10).background(Color.surface, in: RoundedRectangle(cornerRadius: 26))
                        if conversation.draft.count > 4000 { Text(L("这一条有点长，请缩短到 4000 字以内。")) .font(.caption2) }
                        Text(L("AI 陪你探索，不替代专业心理服务。")) .font(.system(size: 10)).foregroundStyle(Color.muted)
                    }.padding(.horizontal, 18).padding(.vertical, 9).background(Color.paper)
                }
            }
            .task { if let api, api.signedIn { conversation.begin(api: api) } }
            .sheet(isPresented: $showAccount, onDismiss: { if api?.signedIn == true { perform(intent) } }) {
                NavigationStack { CloudAccountView().toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("完成")) { showAccount = false } } } }
            }
            .fullScreenCover(isPresented: $showCall) { if let api { VoiceCallView(api: api) } }
            .alert(L("开始另一种探索？"), isPresented: $confirmModeChange) {
                Button(L("切换并开始新对话")) { if let pendingMode { switchMode(pendingMode) } }
                Button(L("取消"), role: .cancel) { pendingMode = nil }
            } message: { Text(L("当前聊天将结束，已生成的回顾会保留。取消可继续当前对话。")) }
            .sheet(item: $selectedReport) { CompanionReportView(report: $0) }
            .onChange(of: conversation.report?.id) { _, _ in if let report = conversation.report { _ = store.keepConversationReport(report) } }
            .onDisappear { if !showCall { conversation.cancel() } }
    }
    private var modePicker: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(CompanionMode.allCases) { mode in
                    Button {
                        guard mode != conversation.mode else { return }
                        writing = false
                        if conversation.userCount > 0 || !conversation.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            pendingMode = mode; confirmModeChange = true
                        } else { switchMode(mode) }
                    } label: {
                        HStack(spacing: 8) {
                            Circle().fill(mode.color).frame(width: 8, height: 8)
                            Text(mode.title).font(.system(size: 13, weight: conversation.mode == mode ? .semibold : .regular)).lineLimit(1).minimumScaleFactor(0.85)
                            Spacer(minLength: 0)
                            if conversation.mode == mode { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)) }
                        }.padding(.horizontal, 12).padding(.vertical, 11)
                            .background(conversation.mode == mode ? mode.color.opacity(0.15) : Color.surface, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(conversation.mode == mode ? mode.color.opacity(0.65) : .clear, lineWidth: 1))
                    }.buttonStyle(.plain).accessibilityIdentifier("chat.mode.\(mode.rawValue)")
                        .accessibilityAddTraits(conversation.mode == mode ? .isSelected : [])
                }
            }
            Text(conversation.mode.detail).font(.caption).foregroundStyle(Color.muted).multilineTextAlignment(.center).accessibilityIdentifier("chat.mode.detail")
        }.padding(.horizontal, 26).padding(.vertical, 10).frame(maxWidth: 640).frame(maxWidth: .infinity)
    }
    private func switchMode(_ mode: CompanionMode) {
        writing = false; conversation.selectMode(mode); pendingMode = nil
        if let api, api.signedIn { conversation.begin(api: api) }
    }
    private func perform(_ action: String) {
        guard let api else { return }; intent = action
        guard api.signedIn else { showAccount = true; return }
        writing = false
        switch action {
        case "voice": showCall = true
        case "start": conversation.begin(api: api)
        case "finish": conversation.finish(api: api)
        case "retry": conversation.retry(api: api)
        default: conversation.send(api: api)
        }
    }
}

import SwiftUI

struct AppRootView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var presenting: Bool?
    @State private var conversation = CompanionConversation()
    private var bypass: Bool {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        return args.contains("--uitesting") && !args.contains("--firstlook")
        #else
        return false
        #endif
    }
    var body: some View {
        Group {
            if let presenting {
                if presenting { FirstLookFlowView { self.presenting = false } }
                else { ContentView() }
            } else { Color.paper.ignoresSafeArea() }
        }.environment(conversation)
            .onAppear { if presenting == nil { enter() } }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { conversation.cancel() }
            }
    }
    private func enter() {
        presenting = !bypass && store.data.firstLook?.report == nil && store.data.firstLook?.deferred != true
    }
}

struct FirstLookFlowView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var requiredEntry = false
    var onFinish: (() -> Void)? = nil
    @State private var started = false
    @State private var index = 0
    @State private var confirmRetake = false
    @State private var generating = false
    @State private var generationError: String?
    @State private var showAccount = false
    @State private var requestTask: Task<Void, Never>?
    var body: some View {
        NavigationStack {
            Group {
                if generating {
                    ReflectionLoadingView(title: L("正在把你的回答，写成一封信。"), detail: L("十个选择都已收到。留一点时间，让文字慢慢靠近你。")) { requestTask?.cancel(); generating = false }
                } else if let report = store.data.firstLook?.report, store.data.firstLook?.isRetaking != true {
                    FirstLookReportView(report: report, onFinish: finish, onRetake: { confirmRetake = true })
                } else if started { question }
                else { welcome }
            }.pageStyle()
                .toolbar(.hidden, for: .navigationBar)
                .confirmationDialog(L("重新回答会替换这份报告。已经保存到相册的图片不会改变。"), isPresented: $confirmRetake, titleVisibility: .visible) {
                    Button(L("重新认识此刻的自己")) {
                        // Keep the existing report until a replacement is saved successfully.
                        var state = store.data.firstLook ?? FirstLookState()
                        state.answers = [:]; state.currentIndex = 0; state.isRetaking = true
                        if store.updateFirstLook(state) { index = 0; started = true }
                    }
                }
                .onAppear { index = min(9, max(0, store.data.firstLook?.currentIndex ?? 0)) }
                .sheet(isPresented: $showAccount, onDismiss: { if signedIn { complete() } }) {
                    NavigationStack { CloudAccountView().toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("完成")) { showAccount = false } } } }
                }
                .onDisappear { requestTask?.cancel(); generating = false }
        }.preferredColorScheme(AppPreferences.shared.colorScheme)
            .environment(\.locale, AppPreferences.shared.locale)
            .interactiveDismissDisabled()
    }
    private var languageControl: some View {
        Button {
            AppPreferences.shared.language = AppPreferences.shared.language == "zh" ? "en" : "zh"
        } label: { Text(AppPreferences.shared.language == "en" ? "简体中文" : "English").font(.system(size: 12)) }
            .accessibilityIdentifier("firstlook.language")
    }
    private var welcome: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                HStack { Eyebrow(text: "INVERTER / 01"); Spacer(); languageControl }
                OrbitArtwork().frame(height: 180).padding(.top, 12)
                Text(L("先不急着成为谁。\n先听听，你自己。")).font(.system(size: 36, weight: .medium)).lineSpacing(7).fixedSize(horizontal: false, vertical: true)
                Text(L("十个问题，写成一封给你的短笺。\n关于你怎样靠近别人，也关于你希望怎样被对待。"))
                    .font(.system(size: 16)).foregroundStyle(Color.muted).lineSpacing(7)
                HStack(spacing: 18) { Label(L("约 3 分钟"), systemImage: "clock"); Label(L("没有人格代码"), systemImage: "circle.dotted") }.font(.caption).foregroundStyle(Color.muted)
                Button {
                    started = true
                } label: { HStack { Text(store.data.firstLook?.answers.isEmpty == false ? L("继续上次的回答") : L("留一点时间，给自己")); Spacer(); Image(systemName: "arrow.right") }.padding(.horizontal, 18) }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("firstlook.start")
                if !requiredEntry { Button(L("以后再说，先看看")) { deferAndFinish() }.font(.subheadline).frame(maxWidth: .infinity).accessibilityIdentifier("firstlook.skip") }
                Notice(text: L("这是一份自我探索，不是心理诊断。点击生成后，我们会根据十个回答为你写一封短笺。你可以随时暂停，也可以在「我的」重新回答。"))
            }.padding(28).frame(maxWidth: 600).frame(maxWidth: .infinity)
        }
    }
    private var question: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if FirstLookQuestion.all.indices.contains(index) {
                    let q = FirstLookQuestion.all[index]
                    VStack(alignment: .leading, spacing: 25) {
                        HStack {
                            Button { if index == 0 { started = false } else { index -= 1; persistIndex() } } label: { Image(systemName: "arrow.left").frame(width: 36, height: 36) }.accessibilityLabel(L("上一题"))
                            Spacer(); languageControl
                            if !requiredEntry { Button(L("暂存并离开")) { deferAndFinish() }.font(.caption).padding(.leading, 12) }
                        }.id("question.top")
                        HStack { Eyebrow(text: L("认识此刻的你")); Spacer(); Text(String(format: "%02d / 10", index + 1)).font(.caption.monospaced()).accessibilityIdentifier("firstlook.progress") }
                        HStack(spacing: 5) { ForEach(0..<10) { i in Capsule().fill(i <= index ? Color.ink : Color.line).frame(height: 2) } }
                        Text(q.question.text).font(.system(size: 29, weight: .medium)).lineSpacing(7).fixedSize(horizontal: false, vertical: true).padding(.vertical, 15)
                        Text(L("选最接近今天的答案，不必像理想中的自己。")) .font(.caption).foregroundStyle(Color.muted)
                        ForEach(Array(q.options.enumerated()), id: \.element.id) { n, option in
                            let selected = store.data.firstLook?.answers[q.id] == option.id
                            Button { _ = store.answerFirstLook(question: q, option: option) } label: {
                                HStack(alignment: .center, spacing: 14) {
                                    Text(String(UnicodeScalar(65 + n)!)).font(.caption.monospaced()).foregroundStyle(Color.muted)
                                    Text(option.text.text).font(.system(size: 16)).multilineTextAlignment(.leading).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
                                    Spacer(minLength: 4)
                                    Image(systemName: selected ? "checkmark.circle.fill" : "circle").foregroundStyle(selected ? Color.ink : Color.line)
                                }.padding(19).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.surface, in: RoundedRectangle(cornerRadius: 16))
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? Color.ink : .clear, lineWidth: 1))
                            }.buttonStyle(.plain).accessibilityIdentifier("firstlook.option.\(n)")
                                .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                        Button {
                            if index == 9 { complete() }
                            else { index += 1; persistIndex(); proxy.scrollTo("question.top", anchor: .top) }
                        } label: { HStack { Text(generating ? L("正在为你写一封短笺…") : index == 9 ? L("收下给自己的短笺") : L("下一题")); Spacer(); Image(systemName: "arrow.right") }.padding(.horizontal, 18) }
                            .buttonStyle(PrimaryButtonStyle()).disabled(generating || store.data.firstLook?.answers[q.id] == nil).padding(.top, 8).accessibilityIdentifier("firstlook.next")
                        if let generationError { Text(generationError).font(.caption).foregroundStyle(Color.muted).accessibilityIdentifier("firstlook.error") }
                    }.disabled(generating).padding(25).frame(maxWidth: 600).frame(maxWidth: .infinity)
                } else { EmptySpace(icon: "arrow.clockwise", title: L("问题暂时无法读取"), message: L("请重新打开 App，你已保存的内容仍在。")) }
            }
        }
    }
    private func persistIndex() {
        var state = store.data.firstLook ?? FirstLookState(); state.currentIndex = index; _ = store.updateFirstLook(state)
    }
    private var api: CloudService? { try? CloudService(endpoint: store.data.privacy.endpoint.isEmpty ? CloudService.productionURL : store.data.privacy.endpoint) }
    private var signedIn: Bool { api?.signedIn == true }
    private func complete() {
        guard !generating else { return }
        guard let api, api.signedIn else { showAccount = true; return }
        let answers = store.data.firstLook?.answers ?? [:]
        let language = AppPreferences.shared.language
        guard FirstLookComposer.isComplete(answers) else { return }
        generating = true; generationError = nil
        requestTask = Task {
            do {
                let response = try await FirstLookService(api: api).generate(answers: answers, language: language)
                try Task.checkCancellation()
                var state = store.data.firstLook ?? FirstLookState()
                guard state.answers == answers else { generating = false; return }
                state.report = FirstLookReport(language: language, title: response.title, paragraph: response.paragraph,
                    invitation: response.invitation, source: "ai", evidenceQuestionIDs: response.evidenceQuestionIDs, answers: answers)
                state.deferred = true; state.isRetaking = false
                if !store.updateFirstLook(state) { generationError = store.persistenceError }
            } catch { if !Task.isCancelled { generationError = L("短笺暂时没有写成，你的回答都在。请稍后再试。") } }
            if !Task.isCancelled { generating = false }
        }
    }
    private func deferAndFinish() {
        var state = store.data.firstLook ?? FirstLookState(); state.deferred = true
        if store.updateFirstLook(state) { finish() }
    }
    private func finish() { if let onFinish { onFinish() } else { dismiss() } }
}

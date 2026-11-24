import SwiftUI

struct CloudAccountView: View {
    @Environment(AppStore.self) private var store
    @State private var phone = ""
    @State private var code = ""
    @State private var busy = false
    @State private var status: String?
    @State private var signedIn = false
    @State private var resendAt = Date.distantPast
    private var endpoint: String { store.data.privacy.endpoint.isEmpty ? CloudService.productionURL : store.data.privacy.endpoint }
    private var validPhone: Bool { phone.range(of: #"^1[3-9][0-9]{9}$"#, options: .regularExpression) != nil }
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: signedIn ? "checkmark.shield" : "person.crop.circle").font(.system(size: 36, weight: .ultraLight))
                    Text(signedIn ? L("欢迎回来。") : L("让理解，再深一点。")).font(.title2.weight(.medium))
                    Text(L("登录后，继续你的探索。你的回答只会用于你正在请求的理解与回应。"))
                        .font(.caption).foregroundStyle(Color.muted)
                }.padding(.vertical, 14)
            }
            if signedIn {
                Section {
                    Label(L("已登录"), systemImage: "checkmark.circle")
                    Button(L("退出登录"), role: .destructive) {
                        if let api = try? CloudService(endpoint: endpoint) { SessionVault.delete(api.origin) }
                        signedIn = false; status = nil
                    }
                }
            } else {
                Section {
                    HStack { Text("+86").foregroundStyle(Color.muted); TextField(L("中国大陆手机号"), text: $phone).keyboardType(.phonePad).textContentType(.telephoneNumber).accessibilityIdentifier("account.phone") }
                    HStack {
                        TextField(L("六位验证码"), text: $code).keyboardType(.numberPad).textContentType(.oneTimeCode).accessibilityIdentifier("account.code")
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let seconds = max(0, Int(ceil(resendAt.timeIntervalSince(context.date))))
                            Button(seconds > 0 ? "\(seconds)s" : L("获取验证码")) {
                                perform {
                                    try await CloudService(endpoint: endpoint).sendCode(phone: phone)
                                    resendAt = Date().addingTimeInterval(60); status = L("验证码已发送，请查看短信。")
                                }
                            }.disabled(busy || !validPhone || seconds > 0)
                        }
                    }
                    Button { perform {
                        try await CloudService(endpoint: endpoint).signIn(phone: phone, code: code)
                        signedIn = true; code = ""; status = nil
                    } } label: { HStack { Text(L("验证并登录")); Spacer(); if busy { ProgressView() } } }
                        .disabled(busy || !validPhone || code.range(of: #"^[0-9]{6}$"#, options: .regularExpression) == nil).accessibilityIdentifier("account.login")
                } header: { Text(L("短信登录")) } footer: { Text(L("点击获取验证码会发送一条登录短信。未注册的号码由原服务自动创建账户。")) }
            }
            if let status { Section { Text(status).font(.subheadline) } }
            Section {
                NavigationLink { PrivacyView() } label: { Text(L("隐私与数据")) }
                Button(L("检查服务连接")) { perform {
                    _ = try await CloudService(endpoint: endpoint).request(path: "health/ready")
                    status = L("连接正常，可以继续。")
                } }.disabled(busy)
            }
        }.navigationTitle(L("账户")).navigationBarTitleDisplayMode(.inline)
            .task { signedIn = (try? CloudService(endpoint: endpoint).signedIn) ?? false }
            .onChange(of: store.data.privacy.endpoint) { _, _ in signedIn = (try? CloudService(endpoint: endpoint).signedIn) ?? false }
    }
    private func perform(_ action: @escaping @MainActor () async throws -> Void) {
        busy = true; status = nil
        Task { do { try await action() } catch { status = error.localizedDescription }; busy = false }
    }
}

/// Sends only the feature's supplied context when the user asks for a reflection.
struct AIAnalysisCard: View {
    @Environment(AppStore.self) private var store
    let context: String
    var purpose = "reflection"
    @State private var result: CloudAnalysis?
    @State private var error: String?
    @State private var loading = false
    @State private var showAccount = false
    @State private var requestTask: Task<Void, Never>?
    @State private var expanded = false
    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack { Image(systemName: "sparkle"); Text(L("换个角度理解")).font(.headline); Spacer() }
            if let result {
                Text(result.title).font(.title3.weight(.medium))
                Text(result.reason).font(.subheadline).lineSpacing(5)
                Text(result.briefAdvice).font(.subheadline).foregroundStyle(Color.muted).lineSpacing(5)
                DisclosureGroup(L("进一步思考"), isExpanded: $expanded) { Text(result.detailedAdvice).font(.subheadline).lineSpacing(6).padding(.top, 10) }
            } else { Text(L("结合这次记录，获得一个具体的观察和可尝试的下一步。")) .font(.subheadline).foregroundStyle(Color.muted).lineSpacing(5) }
            if let error { Text(error).font(.caption).foregroundStyle(Color.muted) }
            Button { analyze() } label: {
                HStack { Text(loading ? L("正在认真阅读…") : error != nil ? L("重新试一次") : result == nil ? L("帮我理解这一刻") : L("重新分析")); Spacer(); if loading { ProgressView() } else { Image(systemName: "arrow.up.right") } }
            }.disabled(loading || context.isEmpty).accessibilityIdentifier("ai.analyze")
        }.surface()
            .sheet(isPresented: $showAccount, onDismiss: { if (try? api().signedIn) == true { analyze() } }) {
                NavigationStack { CloudAccountView().toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("完成")) { showAccount = false } } } }
            }
            .onDisappear { requestTask?.cancel(); loading = false }
            .onChange(of: store.data.privacy.endpoint) { _, _ in requestTask?.cancel(); result = nil; loading = false }
            .onChange(of: context) { _, _ in requestTask?.cancel(); result = nil; error = nil; loading = false }
    }
    private func api() throws -> CloudService { try CloudService(endpoint: store.data.privacy.endpoint.isEmpty ? CloudService.productionURL : store.data.privacy.endpoint) }
    private func analyze() {
        guard (try? api().signedIn) == true else { showAccount = true; return }
        loading = true; error = nil
        requestTask = Task {
            do { let answer = try await api().analyze(context, purpose: purpose); try Task.checkCancellation(); result = answer }
            catch { if !Task.isCancelled { self.error = error.localizedDescription } }
            if !Task.isCancelled { loading = false }
        }
    }
}

extension LifeEvent {
    var analysisText: String {
        L("事实：\(facts)\n我的感受：\(feeling.label)\n我的解释（未核实）：\(interpretation)\n我在意的：\(need)\n下一步：\(nextStep)\n仍然未知：\(unknown)")
    }
}

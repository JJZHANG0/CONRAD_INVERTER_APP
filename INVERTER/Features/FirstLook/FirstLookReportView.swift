import SwiftUI
import Photos

struct FirstLookReportView: View {
    @Environment(AppStore.self) private var store
    let report: FirstLookReport
    let onFinish: () -> Void
    let onRetake: () -> Void
    @State private var poster: UIImage?
    @State private var sharing: ShareImage?
    @State private var message: String?
    @State private var sending = false
    @State private var requestTask: Task<Void, Never>?
    @State private var showAccount = false
    @State private var saving = false
    private var api: CloudService? { try? CloudService(endpoint: store.data.privacy.endpoint.isEmpty ? CloudService.productionURL : store.data.privacy.endpoint) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack { Eyebrow(text: L("给此刻的你")); Spacer(); Button(L("进入我的空间"), action: onFinish).font(.caption).accessibilityIdentifier("firstlook.finish") }
                Text(L("读一读。\n也可以，留给自己。")).font(.system(size: 31, weight: .medium)).lineSpacing(6)
                if let poster {
                    Image(uiImage: poster).resizable().scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.line, lineWidth: 1))
                        .contextMenu {
                            Button(L("保存报告图片"), systemImage: "square.and.arrow.down") { saveImage() }
                            Button(L("分享报告图片"), systemImage: "square.and.arrow.up") { sharing = ShareImage(image: poster) }
                        }
                        .accessibilityLabel(report.title + ". " + report.paragraph + ". " + report.invitation)
                        .accessibilityIdentifier("firstlook.poster")
                } else { ProgressView().frame(maxWidth: .infinity).padding(50) }
                Text(L("长按图片可以保存或分享。图片只包含短笺，不包含完整答题记录、手机号或姓名。")) .font(.caption).foregroundStyle(Color.muted).lineSpacing(4)
                HStack(spacing: 12) {
                    Button { saveImage() } label: { Label(saving ? L("正在保存…") : L("保存图片"), systemImage: "square.and.arrow.down").frame(maxWidth: .infinity) }.disabled(poster == nil || saving).accessibilityIdentifier("firstlook.saveImage")
                    Button { if let poster { sharing = ShareImage(image: poster) } } label: { Label(L("分享"), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }.disabled(poster == nil).accessibilityIdentifier("firstlook.share")
                }.font(.system(size: 14, weight: .medium)).padding(.vertical, 14)
                Text(L("安装微信后，可在系统分享面板选择微信；也可以先存入相册，再发给朋友。")) .font(.caption2).foregroundStyle(Color.muted)
                Divider()
                Button { generate() } label: {
                    HStack { Text(sending ? L("正在为你写一封短笺…") : L("重新写一封")); Spacer(); if sending { ProgressView() } else { Image(systemName: "arrow.up.right") } }
                }.disabled(sending).accessibilityIdentifier("firstlook.ai")
                DisclosureGroup(L("看看我当时的选择")) {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(FirstLookQuestion.all) { q in
                            if let answer = q.options.first(where: { $0.id == report.answers[q.id] }) {
                                VStack(alignment: .leading, spacing: 6) { Text(q.question.text).font(.caption).foregroundStyle(Color.muted); Text(answer.text.text).font(.subheadline) }
                            }
                        }
                    }.padding(.top, 15)
                }.font(.subheadline)
                Button(L("重新认识此刻的自己"), action: onRetake).font(.subheadline).frame(maxWidth: .infinity)
                Button(L("带着这份理解，开始"), action: onFinish).buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("firstlook.enter")
            }.padding(25).frame(maxWidth: 600).frame(maxWidth: .infinity)
        }
        .task(id: report.id) { poster = FirstLookImageRenderer.render(report) }
        .sheet(item: $sharing) { item in ReportShareSheet(image: item.image) }
        .sheet(isPresented: $showAccount, onDismiss: { if api?.signedIn == true { generate() } }) { NavigationStack { CloudAccountView().toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("完成")) { showAccount = false } } } } }
        .alert(L("给你一个提醒"), isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button(L("知道了"), role: .cancel) {} } message: { Text(message ?? "") }
        .onDisappear { requestTask?.cancel(); sending = false }
    }
    private func generate() {
        guard let api, api.signedIn else { showAccount = true; return }
        sending = true
        requestTask = Task {
            do {
                let response = try await FirstLookService(api: api).generate(answers: report.answers, language: report.language)
                try Task.checkCancellation()
                var state = store.data.firstLook ?? FirstLookState()
                guard state.report?.id == report.id else { sending = false; return }
                var updated = report; updated.id = UUID(); updated.source = "ai"
                updated.title = response.title; updated.paragraph = response.paragraph; updated.invitation = response.invitation; updated.evidenceQuestionIDs = response.evidenceQuestionIDs
                state.report = updated
                if !store.updateFirstLook(state) { message = store.persistenceError }
            } catch { if !Task.isCancelled { message = L("暂时没有写成，当前短笺已保留。请稍后再试。") } }
            if !Task.isCancelled { sending = false }
        }
    }
    private func saveImage() {
        guard let poster, !saving else { return }
        saving = true
        Task {
            defer { saving = false }
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else { message = L("尚未获得保存照片的权限。你可以在系统设置中允许，或使用分享按钮保存到文件。"); return }
            do {
                try await PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.creationRequestForAsset(from: poster) }
                message = L("报告图片已保存到相册。")
            } catch { message = L("图片暂时未能保存，请重试或使用分享。") }
        }
    }
}

private struct ShareImage: Identifiable { let id = UUID(); let image: UIImage }
struct ReportShareSheet: UIViewControllerRepresentable {
    let image: UIImage
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: [image], applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct FirstLookPoster: View {
    let report: FirstLookReport
    private func copy(_ zh: String, _ en: String) -> String { report.language == "zh" ? zh : en }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack { Image(systemName: "arrow.up.arrow.down").font(.system(size: 12, weight: .medium)); Text("INVERTER").font(.system(size: 13, weight: .bold)).tracking(2); Spacer(); Text(copy("01 / 初见", "01 / FIRST LOOK")).font(.system(size: 8, design: .monospaced)).foregroundStyle(.gray) }
            Rectangle().fill(Color.black.opacity(0.16)).frame(height: 0.5)
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(copy("给此刻的你", "A NOTE TO YOU, TODAY")).font(.system(size: 10, weight: .medium)).tracking(2)
                    Text(report.createdAt.formatted(.dateTime.locale(Locale(identifier: report.language)).year().month(.twoDigits).day(.twoDigits))).font(.system(size: 9, design: .monospaced)).foregroundStyle(.gray)
                }
                Spacer(); OrbitArtwork().frame(width: 82, height: 82)
            }
            Text(report.title).font(.system(size: 28, weight: .medium)).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
            Text(report.paragraph).font(.system(size: 16)).lineSpacing(9).fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: 12) {
                Rectangle().fill(.black).frame(width: 2)
                Text(report.invitation).font(.system(size: 16, weight: .medium)).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
            }.fixedSize(horizontal: false, vertical: true).padding(.vertical, 8)
            Rectangle().fill(Color.black.opacity(0.16)).frame(height: 0.5)
            Text(copy("十个问题，靠近自己一点。", "TEN QUESTIONS. A LITTLE CLOSER TO YOURSELF.")).font(.system(size: 9, weight: .medium)).tracking(1.1)
            Text(copy("写给此刻的自己 · 自我探索，非心理诊断", "A note to myself, today · For self-reflection"))
                .font(.system(size: 8)).foregroundStyle(Color(white: 0.42)).lineSpacing(3)
        }.padding(28).frame(width: 360, alignment: .leading).foregroundStyle(.black).background(Color(white: 0.985))
            .environment(\.colorScheme, .light)
    }
}

@MainActor enum FirstLookImageRenderer {
    static func render(_ report: FirstLookReport) -> UIImage? {
        let renderer = ImageRenderer(content: FirstLookPoster(report: report))
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage
    }
}

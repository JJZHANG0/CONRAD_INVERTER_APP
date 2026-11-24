import SwiftUI
import Photos

private struct ConversationShare: Identifiable { let id = UUID(); let image: UIImage }
struct CompanionReportView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let report: CompanionReport
    @State private var poster: UIImage?
    @State private var sharing: ConversationShare?
    @State private var notice: String?
    @State private var saving = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let poster {
                        Image(uiImage: poster).resizable().scaledToFit().accessibilityIdentifier("chat.report.poster")
                            .accessibilityLabel(report.reflection.title + ". " + report.reflection.summary)
                            .contextMenu {
                                Button(L("保存报告图片"), systemImage: "square.and.arrow.down") { save() }
                                Button(L("分享报告图片"), systemImage: "square.and.arrow.up") { sharing = ConversationShare(image: poster) }
                            }
                    } else { ProgressView().padding(80) }
                    HStack(spacing: 24) {
                        Button(L("保存图片"), systemImage: "square.and.arrow.down") { save() }.disabled(poster == nil || saving).accessibilityIdentifier("chat.report.save")
                        Button(L("分享"), systemImage: "square.and.arrow.up") { if let poster { sharing = ConversationShare(image: poster) } }.disabled(poster == nil).accessibilityIdentifier("chat.report.share")
                    }.font(.subheadline)
                    Text(L("分享前请先读一遍。图片不包含对话原文，但回顾本身仍可能涉及你的私人经历。")) .font(.caption).foregroundStyle(Color.muted).lineSpacing(4)
                    DisclosureGroup(L("来自你说过的话")) {
                        ForEach(report.reflection.evidence, id: \.self) { Text($0).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8) }
                    }.font(.subheadline)
                }.padding(22).frame(maxWidth: 620).frame(maxWidth: .infinity)
            }.background(Color.paper).navigationTitle(L("这次对话，留给你")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("完成")) { dismiss() } } }
                .task { _ = store.keepConversationReport(report); poster = ConversationReportRenderer.render(report) }
                .sheet(item: $sharing) { ReportShareSheet(image: $0.image) }
                .alert(L("给你一个提醒"), isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) { Button(L("知道了"), role: .cancel) {} } message: { Text(notice ?? "") }
        }
    }
    private func save() {
        guard let poster, !saving else { return }; saving = true
        Task {
            defer { saving = false }
            let permission = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard permission == .authorized || permission == .limited else { notice = L("尚未获得保存照片的权限。你可以在系统设置中允许，或使用分享按钮保存到文件。"); return }
            do { try await PHPhotoLibrary.shared().performChanges { PHAssetChangeRequest.creationRequestForAsset(from: poster) }; notice = L("报告图片已保存到相册。") }
            catch { notice = L("图片暂时未能保存，请重试或使用分享。") }
        }
    }
}
struct ConversationPoster: View {
    let report: CompanionReport
    private var r: ConversationReflection { report.reflection }
    private func copy(_ zh: String, _ en: String) -> String { report.language == "zh" ? zh : en }
    var body: some View {
        VStack(alignment: .leading, spacing: 27) {
            HStack { Text("INVERTER").font(.system(size: 11, weight: .semibold)).tracking(3); Spacer(); Text("REFLECTION / 01").font(.system(size: 8, design: .monospaced)).foregroundStyle(.gray) }
            Rectangle().fill(Color.black.opacity(0.18)).frame(height: 0.5)
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(copy("这次对话，留给你", "FROM OUR CONVERSATION")).font(.system(size: 10)).tracking(1.4)
                    if let mode = report.mode { Text(mode.title(language: report.language)).font(.system(size: 10, weight: .medium)).foregroundStyle(mode.color) }
                    Text(report.createdAt.formatted(.dateTime.locale(Locale(identifier: report.language)).year().month(.twoDigits).day(.twoDigits))).font(.system(size: 9, design: .monospaced)).foregroundStyle(.gray)
                }
                Spacer()
                ZStack {
                    Circle().fill(report.mode?.color ?? .black).frame(width: 44, height: 44)
                    HStack(spacing: 5) { Capsule().fill(report.mode == nil ? .white : .black).frame(width: 4, height: 12); Capsule().fill(report.mode == nil ? .white : .black).frame(width: 4, height: 12) }.rotationEffect(.degrees(-20)).offset(x: 5, y: -4)
                }
            }
            Text(r.title).font(.system(size: 29, weight: .medium)).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
            Text(r.summary).font(.system(size: 16)).lineSpacing(8).fixedSize(horizontal: false, vertical: true)
            section(copy("01 / 一条值得留意的线索", "01 / A PATTERN TO EXPLORE"), r.pattern)
            section(copy("02 / 你已经拥有的力量", "02 / STRENGTHS YOU HAVE SHOWN"), r.strengths)
            section(copy("03 / 一个小小的下一步", "03 / ONE SMALL NEXT STEP"), r.nextStep)
            Text(r.invitation).font(.system(size: 18, weight: .medium)).lineSpacing(6).padding(.leading, 14).overlay(alignment: .leading) { Rectangle().fill(.black).frame(width: 2) }.fixedSize(horizontal: false, vertical: true)
            Rectangle().fill(Color.black.opacity(0.18)).frame(height: 0.5)
            Text(copy("对话回顾 · 自我探索，非心理诊断", "A conversation reflection · Not a clinical assessment")).font(.system(size: 8)).foregroundStyle(.gray)
        }.padding(30).frame(width: 390, alignment: .leading).foregroundStyle(.black).background(Color.white).environment(\.colorScheme, .light)
    }
    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 9, weight: .medium)).tracking(1).foregroundStyle(.gray)
            Text(body).font(.system(size: 15)).lineSpacing(7).fixedSize(horizontal: false, vertical: true)
        }
    }
}
@MainActor enum ConversationReportRenderer {
    static func render(_ report: CompanionReport) -> UIImage? {
        let renderer = ImageRenderer(content: ConversationPoster(report: report)); renderer.scale = 3; renderer.isOpaque = true; return renderer.uiImage
    }
}

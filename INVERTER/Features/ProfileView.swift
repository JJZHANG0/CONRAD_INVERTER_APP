import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct ProfileView: View {
    @State private var firstLook = false
    @Environment(AppStore.self) private var store
    var body: some View {
        @Bindable var store = store
        ScrollView {
            VStack(alignment: .leading, spacing: 27) {
                HStack { Eyebrow(text: L("你的私人空间")); Spacer(); Image(systemName: "lock.shield").font(.system(size: 20, weight: .light)).foregroundStyle(Color.crystal) }
                NavigationLink { ProfileEditor() } label: {
                    HStack(spacing: 19) {
                        Text(String(store.data.profile.name.prefix(1))).font(.system(size: 27, weight: .light)).foregroundStyle(Color.crystal).frame(width: 70, height: 70).background(Color.surface, in: Circle())
                        VStack(alignment: .leading, spacing: 9) { Text(store.data.profile.name).font(.system(size: 29, weight: .medium)); Text(store.data.profile.intention).font(.system(size: 12)).foregroundStyle(Color.muted) }
                        Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.muted)
                    }
                }.buttonStyle(.plain)
                HStack(spacing: 0) {
                    count(L("真实记录"), value: store.data.events.count)
                    count(L("探索体验"), value: store.data.gameResults.count)
                    count(L("个人连接"), value: store.data.people.count)
                }.padding(.vertical, 12)
                Button { firstLook = true } label: { RowLink(icon: "rectangle.portrait", title: L("给自己的第一封短笺"), detail: store.data.firstLook?.report == nil ? L("十个问题") : L("查看报告")) }.buttonStyle(.plain).accessibilityIdentifier("profile.firstlook")
                NavigationLink { CloudAccountView() } label: { RowLink(icon: "sparkle", title: L("账户"), detail: L("通义千问")) }.accessibilityIdentifier("profile.account")
                VStack(spacing: 0) {
                    NavigationLink { PortraitView() } label: { RowLink(icon: "circle.dotted.circle", title: L("我的认知档案")) }; Divider()
                    NavigationLink { HistoryView() } label: { RowLink(icon: "text.book.closed", title: L("历史记录"), detail: "\(store.data.events.count)") }.accessibilityIdentifier("profile.history"); Divider()
                    NavigationLink { HistoryView(favoritesOnly: true) } label: { RowLink(icon: "bookmark", title: L("我的收藏")) }; Divider()
                    NavigationLink { GameHistoryView() } label: { RowLink(icon: "sparkles", title: L("游戏记录")) }; Divider()
                    NavigationLink { ChallengeView() } label: { RowLink(icon: "flag", title: L("成长挑战"), detail: "\(store.data.challenge.completed.count) / 4") }
                }
                VStack(alignment: .leading, spacing: 16) {
                    HStack { Image(systemName: "square.stack.3d.up").font(.system(size: 23, weight: .light)).foregroundStyle(Color.crystal); Spacer(); Tag(text: L("由你掌控"), color: .sage) }
                    Text(L("被记住的，\n由你决定。")) .font(.system(size: 25, weight: .medium)).lineSpacing(7)
                    Text(L("查看、修正或删除每一条长期记忆。")) .font(.system(size: 12)).foregroundStyle(Color.muted)
                    NavigationLink { MemoryView() } label: { HStack { Text(L("管理 AI 记忆")); Spacer(); Text(L("\(store.data.memories.count) 条")); Image(systemName: "arrow.right") }.font(.system(size: 13, weight: .medium)) }.padding(.top, 10)
                }.surface()
                VStack(spacing: 0) {
                    NavigationLink { PrivacyView() } label: { RowLink(icon: "hand.raised", title: L("隐私与数据")) }; Divider()
                    NavigationLink { NotificationSettingsView() } label: { RowLink(icon: "bell", title: L("提醒设置")) }; Divider()
                    NavigationLink { AppearanceSettingsView() } label: { RowLink(icon: "globe", title: L("外观与语言"), detail: AppPreferences.shared.language == "en" ? "English" : L("简体中文")) }.accessibilityIdentifier("profile.appearance"); Divider()
                    NavigationLink { AppInfoView(kind: .membership) } label: { RowLink(icon: "circle.hexagongrid", title: L("订阅与会员"), detail: L("原型体验")) }; Divider()
                    NavigationLink { AppInfoView(kind: .about) } label: { RowLink(icon: "info.circle", title: L("关于 INVERTER")) }
                }
                Toggle(isOn: $store.data.showDemo) {
                    VStack(alignment: .leading, spacing: 5) { Text(L("展示示例空间")).font(.system(size: 13)); Text(L("示例不会计入你的个人记录与记忆")).font(.system(size: 10)).foregroundStyle(Color.muted) }
                }.tint(.crystal).onChange(of: store.data.showDemo) { _, _ in store.save() }.accessibilityIdentifier("profile.demo")
                Text(L("INVERTER\n理解他人，也理解自己。")).font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(1.5).lineSpacing(9).foregroundStyle(Color.muted.opacity(0.7)).multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.vertical, 13)
            }.padding(25).padding(.top, 12).frame(maxWidth: 680).frame(maxWidth: .infinity)
        }.pageStyle().toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $firstLook) { FirstLookFlowView { firstLook = false } }
    }
    private func count(_ title: String, value: Int) -> some View { VStack(spacing: 9) { Text(String(format: "%02d", value)).font(.system(size: 29, weight: .light, design: .rounded)); Text(title).font(.system(size: 10)).foregroundStyle(Color.muted) }.frame(maxWidth: .infinity) }
}

struct ProfileEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var intention = ""
    var body: some View {
        Form {
            Section(L("如何称呼你")) { TextField(L("昵称"), text: $name) }
            Section(L("给自己的一句话")) { TextField(L("此刻的期待"), text: $intention, axis: .vertical) }
            Section { Text(L("无需实名，也无需注册。当前档案保存在这台设备上。")).font(.caption).foregroundStyle(Color.muted) }
        }.navigationTitle(L("个人资料")).navigationBarTitleDisplayMode(.inline)
            .toolbar { Button(L("保存")) { store.data.profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines); store.data.profile.intention = intention; store.save(); dismiss() }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            .onAppear { name = store.data.profile.name; intention = store.data.profile.intention }
    }
}

struct MemoryView: View {
    @Environment(AppStore.self) private var store
    @State private var filter: MemoryKind?
    @State private var editing: Memory?
    @State private var deleting: UUID?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeading(eyebrow: L("记忆，始于你的允许"), title: L("我记得的，由你定义。"), subtitle: L("记忆与事件独立管理。删除记忆不会删除原始经历。"))
                NavigationLink { PrivacyView() } label: { RowLink(icon: "slider.horizontal.3", title: L("管理记忆保存授权")) }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack { Button { filter = nil } label: { Tag(text: L("全部"), color: filter == nil ? .ink : .muted) }; ForEach(MemoryKind.allCases) { kind in Button { filter = kind } label: { Tag(text: kind.label, color: filter == kind ? .ink : .muted) } } }
                }
                let memories = store.data.memories.filter { filter == nil || $0.kind == filter }
                if memories.isEmpty { EmptySpace(icon: "square.stack.3d.up", title: L("这里，留给你允许记住的事。"), message: L("默认不保存长期记忆。开启类别授权后，每次复盘仍需你单独确认。")) }
                ForEach(memories) { memory in
                    VStack(alignment: .leading, spacing: 18) {
                        HStack { Tag(text: memory.kind.label); Spacer(); Text(memory.date.formatted(.dateTime.locale(AppPreferences.shared.locale).month().day())).font(.caption2).foregroundStyle(Color.muted) }
                        Text(memory.text).font(.system(size: 16)).lineSpacing(6)
                        HStack(spacing: 22) {
                            if let id = memory.eventID, store.event(id) != nil { NavigationLink(L("查看来源")) { EventDetailView(eventID: id) } }
                            if let id = memory.gameResultID, let result = store.data.gameResults.first(where: { $0.id == id }) { NavigationLink(L("查看报告")) { GameReportView(result: result) } }
                            Spacer()
                            Button(L("修正")) { editing = memory }
                            Button { deleting = memory.id } label: { Image(systemName: "trash") }.accessibilityLabel(L("删除记忆"))
                        }.font(.system(size: 12)).foregroundStyle(Color.crystal)
                    }.surface()
                }
            }.padding(25).frame(maxWidth: 680).frame(maxWidth: .infinity)
        }.pageStyle().navigationTitle(L("AI 记忆管理")).navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editing) { memory in MemoryEditor(memory: memory) }
            .confirmationDialog(L("删除这条记忆？原始记录会保留。"), isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) { Button(L("删除记忆"), role: .destructive) { store.data.memories.removeAll { $0.id == deleting }; store.save(); deleting = nil } }
    }
}
struct MemoryEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var memory: Memory
    var body: some View {
        NavigationStack {
            Form {
                Section(L("准确的理解应该是什么？")) { TextField(L("记忆内容"), text: $memory.text, axis: .vertical).lineLimit(5...12) }
                Section { Text(L("原内容会被替换，并标记为「已修正」。不会继续沿用原先的判断。")).font(.caption).foregroundStyle(Color.muted) }
            }.navigationTitle(L("修正记忆")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("取消")) { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button(L("保存")) { if let index = store.data.memories.firstIndex(where: { $0.id == memory.id }) { memory.kind = .correction; memory.date = Date(); store.data.memories[index] = memory; store.save() }; dismiss() }.disabled(memory.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } }
        }
    }
}

struct ArchiveDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
struct PrivacyView: View {
    @Environment(AppStore.self) private var store
    @Environment(CompanionConversation.self) private var conversation
    @State private var exporting = false
    @State private var exportData = Data()
    @State private var exportError: String?
    @State private var erase = false
    @State private var eraseMemories = false
    var body: some View {
        @Bindable var store = store
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) { Image(systemName: "lock.shield").font(.system(size: 30, weight: .light)).foregroundStyle(Color.crystal); Text(L("你的经历，你的选择。")).font(.title2.weight(.medium)); Text(L("你的记录由你掌握。生成短笺、对话、追问和回顾时，相关文字会发送至我们的服务及千问平台；不会附带其他档案或图片。语音在设备端识别和朗读，只发送识别后的文字。对话回顾保存在本机，可随档案导出或清除。")).font(.caption).foregroundStyle(Color.muted).lineSpacing(5) }.padding(.vertical, 12)
            }
            Section {
                Text(L("通讯录人物只在你选择并确认导入后保存在本机。导入姓名、头像、生日和组织信息；不保存电话或邮箱，不写回通讯录。人物资料与亲密程度不会自动用于 AI 分析。")) .font(.caption).foregroundStyle(Color.muted).lineSpacing(4)
            }
            Section {
                Toggle(L("允许记住明确表达的事实"), isOn: $store.data.privacy.saveFacts)
                Toggle(L("允许记住个人感受"), isOn: $store.data.privacy.saveFeelings)
                Toggle(L("允许记住游戏探索结果"), isOn: $store.data.privacy.saveGameResults)
            } header: { Text(L("长期记忆 · 默认关闭")) } footer: { Text(L("关闭类别仅停止新增记忆，不会删除已有内容。复盘保存时仍需单独确认；游戏结果在授权后以「个人解释」保存。")) }
            Section(L("你的数据")) {
                Button(L("导出个人档案（JSON）")) {
                    do { let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; exportData = try encoder.encode(store.data); exporting = true } catch { exportError = error.localizedDescription }
                }
                Button(L("删除全部长期记忆"), role: .destructive) { eraseMemories = true }
                Button(L("清除本机全部数据"), role: .destructive) { erase = true }
            }
            Section { Text(L("导出文件包含你保存的记录及图片附件，请选择自己控制的存储位置。系统设备备份可能包含本机档案；你可以在系统设置管理备份。当前没有账户同步或服务端删除功能。")).font(.caption).foregroundStyle(Color.muted).lineSpacing(4) }
        }.tint(.crystal).navigationTitle(L("隐私与数据")).navigationBarTitleDisplayMode(.inline)
            .onChange(of: store.data.privacy.saveFacts) { _, _ in store.save() }
            .onChange(of: store.data.privacy.saveFeelings) { _, _ in store.save() }
            .onChange(of: store.data.privacy.saveGameResults) { _, _ in store.save() }
            .fileExporter(isPresented: $exporting, document: ArchiveDocument(data: exportData), contentType: .json, defaultFilename: L("INVERTER-个人档案")) { result in if case .failure(let error) = result { exportError = error.localizedDescription } }
            .alert(L("导出失败"), isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) { Button(L("知道了"), role: .cancel) {} } message: { Text(exportError ?? "") }
            .confirmationDialog(L("清除全部个人记录、人物、游戏结果、挑战与设置？此操作无法撤销。"), isPresented: $erase, titleVisibility: .visible) { Button(L("永久清除本机数据"), role: .destructive) { conversation.reset(); store.eraseAll(); UNUserNotificationCenter.current().removeAllPendingNotificationRequests() } }
            .confirmationDialog(L("删除全部长期记忆？历史记录和游戏报告仍然保留。"), isPresented: $eraseMemories, titleVisibility: .visible) { Button(L("删除全部记忆"), role: .destructive) { store.data.memories.removeAll(); store.save() } }
    }
}

struct NotificationSettingsView: View {
    @State private var enabled = false
    @State private var time = Calendar.current.date(from: DateComponents(hour: 21)) ?? Date()
    @State private var message: String?
    @State private var busy = false
    private let identifier = "inverter.daily-reflection"
    var body: some View {
        Form {
            Section {
                Toggle(L("每天给自己留一个片刻"), isOn: $enabled)
                if enabled { DatePicker(L("提醒时间"), selection: $time, displayedComponents: .hourAndMinute) }
                Button(busy ? L("正在保存…") : L("保存提醒设置")) { Task { await update() } }.disabled(busy)
            } footer: { Text(L("提醒完全可选。关闭后会移除本 App 的每日提醒。")) }
            if let message { Section { Text(message).font(.subheadline).foregroundStyle(Color.muted) } }
        }.navigationTitle(L("提醒设置")).navigationBarTitleDisplayMode(.inline)
            .task {
                let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
                if let request = requests.first(where: { $0.identifier == identifier }), let trigger = request.trigger as? UNCalendarNotificationTrigger { enabled = true; time = Calendar.current.date(from: trigger.dateComponents) ?? time }
            }
    }
    private func update() async {
        busy = true
        defer { busy = false }
        let center = UNUserNotificationCenter.current()
        if !enabled { center.removePendingNotificationRequests(withIdentifiers: [identifier]); message = L("每日提醒已关闭。"); return }
        do {
            let allowed = try await center.requestAuthorization(options: [.alert, .sound])
            guard allowed else { enabled = false; message = L("通知权限未开启，可在系统设置中允许。"); return }
            let content = UNMutableNotificationContent(); content.title = L("留一个片刻，给自己。"); content.body = L("今天，有什么值得你停下来想一想？"); content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.hour, .minute], from: time), repeats: true)
            try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
            message = L("已设置每日 \(time.formatted(.dateTime.hour().minute())) 提醒。")
        } catch { message = L("提醒未能保存：\(error.localizedDescription)") }
    }
}

struct AppInfoView: View {
    enum Kind { case about, membership, language }
    let kind: Kind
    private var title: String { switch kind { case .about: L("关于 INVERTER"); case .membership: L("订阅与会员"); case .language: L("语言") } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                OrbitArtwork().frame(height: 190).frame(maxWidth: .infinity)
                Eyebrow(text: L("理解他人，也理解自己。"))
                Text(title).font(.system(size: 30, weight: .medium))
                if kind == .about {
                    Text(L("一个安静的个人认知空间。")).font(.title3)
                    Text(L("通过真实的经历，理解自己、理解他人。你可以修正任何理解，也始终拥有自己的记录。")).foregroundStyle(Color.muted).lineSpacing(7)
                    Divider()
                    Text(L("INVERTER 1.0\n理解他人，也慢慢理解自己。")) .font(.subheadline).foregroundStyle(Color.muted).lineSpacing(8)
                    Notice(text: L("INVERTER 用于日常记录与自我探索，不提供临床诊断或治疗。"))
                } else if kind == .membership {
                    Tag(text: L("当前原型 · 全部功能开放"), color: .sage)
                    Text(L("安心探索，不用订阅。")).font(.title2)
                    Text(L("当前没有付费套餐，不会产生订阅或扣费。后续正式服务如有收费，会在购买前明确说明。")).foregroundStyle(Color.muted).lineSpacing(7)
                } else {
                    HStack { Text(L("简体中文")); Spacer(); Image(systemName: "checkmark").foregroundStyle(Color.crystal) }.surface()
                    Text(L("当前原型以简体中文提供完整体验。工程已建立字符串资源入口，英文翻译将在内容完善后开放。")).foregroundStyle(Color.muted).lineSpacing(7)
                }
            }.padding(25).frame(maxWidth: 680).frame(maxWidth: .infinity)
        }.pageStyle().navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
}

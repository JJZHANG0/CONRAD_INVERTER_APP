import SwiftUI
import PhotosUI

struct ReviewView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var personID: UUID? = nil
    var sourceEvent: LifeEvent? = nil
    @State private var step = 0
    @State private var input = ""
    @State private var facts = ""
    @State private var interpretation = ""
    @State private var need = ""
    @State private var action = ""
    @State private var emotion: Emotion = .calm
    @State private var selectedPeople: Set<UUID> = []
    @State private var remember = false
    @State private var photo: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var speech = SpeechCapture()
    @State private var turns: [ReflectionTurn] = []
    @State private var cloudQuestion: String?
    @State private var loading = false
    @State private var error: String?
    @State private var saved = false
    @State private var savedID: UUID?
    @State private var discard = false
    @State private var showAccount = false
    @State private var requestTask: Task<Void, Never>?
    @State private var voicePrefix = ""
    @FocusState private var focused: Bool

    private let questions = [L("发生了什么，\n让你想停下来聊一聊？"), L("回到那个时刻，\n你的感受是什么？"), L("你是怎样理解\n这件事的？"), L("这件事里，\n你真正希望的是什么？"), L("接下来，\n想尝试哪一个小行动？")]
    private let hints = [L("从一个具体片段开始。不需要完整，也不用急着解释。"), L("没有正确的感受。选一个最接近此刻的词。"), L("这是你的理解，不一定是已经核实的事实。"), L("被理解、清晰的沟通，或是属于自己的空间。"), L("可以很小，也可以先不行动。")]
    var body: some View {
        NavigationStack {
            Group {
                if saved { completion }
                else if step == 5 { confirmation }
                else { conversation }
            }.pageStyle().navigationTitle(saved ? L("已收好这段经历") : L("一个理解自己的片刻")).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { if saved || (step == 0 && input.isEmpty && imageData == nil) { dismiss() } else { discard = true } } label: { Image(systemName: "xmark").font(.system(size: 13, weight: .medium)) }.accessibilityLabel(L("关闭复盘"))
                    }
                }
                .confirmationDialog(L("离开后，本次未保存的内容将被丢弃。"), isPresented: $discard, titleVisibility: .visible) { Button(L("丢弃并离开"), role: .destructive) { dismiss() } }
                .alert(L("暂时无法继续"), isPresented: Binding(get: { error != nil || speech.error != nil }, set: { if !$0 { error = nil; speech.error = nil } })) { Button(L("知道了"), role: .cancel) {} } message: { Text(error ?? speech.error ?? "") }
                .interactiveDismissDisabled(!saved && (step > 0 || !input.isEmpty || imageData != nil))
                .onAppear {
                    if let personID, store.person(personID)?.isDemo == false { selectedPeople.insert(personID) }
                    if let sourceEvent, !sourceEvent.isDemo { input = sourceEvent.facts; selectedPeople = Set(sourceEvent.personIDs.filter { store.person($0)?.isDemo == false }) }
                }
                .sheet(isPresented: $showAccount, onDismiss: { if api?.signedIn == true { advance() } }) {
                    NavigationStack { CloudAccountView().toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("完成")) { showAccount = false } } } }
                }
                .onDisappear { speech.stop(); requestTask?.cancel(); loading = false }
                .onChange(of: speech.transcript) { _, value in if !value.isEmpty { input = voicePrefix + value } }
                .onChange(of: photo) { _, value in
                    Task {
                        do {
                            guard let data = try await value?.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return }
                            let ratio = min(1, 1400 / max(image.size.width, image.size.height))
                            let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
                            imageData = UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }.jpegData(compressionQuality: 0.75)
                        } catch { self.error = L("图片读取失败，请重新选择。") }
                    }
                }
        }
    }
    private var conversation: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack(spacing: 5) { ForEach(0..<5) { i in Capsule().fill(i <= step ? Color.ink : Color.line).frame(height: 3) } }.padding(.top, 15)
                HStack { Eyebrow(text: L("复盘 / 0\(step + 1)")); Spacer(); Text("\(step + 1) / 5").font(.system(size: 11, design: .monospaced)).foregroundStyle(Color.muted) }
                Image(systemName: "waveform.path").font(.system(size: 29, weight: .ultraLight)).foregroundStyle(Color.crystal).padding(.top, 10)
                Text(cloudQuestion ?? questions[step]).font(.system(size: 29, weight: .medium)).lineSpacing(9).fixedSize(horizontal: false, vertical: true)
                Text(hints[step]).font(.system(size: 13)).foregroundStyle(Color.muted).lineSpacing(5)
                if step == 1 {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(Emotion.allCases) { feeling in
                            Button { emotion = feeling; UISelectionFeedbackGenerator().selectionChanged() } label: {
                                VStack(spacing: 13) { Image(systemName: feeling.symbol).font(.system(size: 25, weight: .light)); Text(feeling.label).font(.system(size: 13)) }.frame(maxWidth: .infinity).padding(.vertical, 23).background(emotion == feeling ? feeling.color.opacity(0.1) : Color.surface, in: RoundedRectangle(cornerRadius: 15)).overlay(RoundedRectangle(cornerRadius: 15).stroke(emotion == feeling ? feeling.color : .clear, lineWidth: 1)).foregroundStyle(feeling.color)
                            }
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField(step == 0 ? L("从这里开始……") : L("写下此刻真实的想法……"), text: $input, axis: .vertical)
                            .lineLimit(5...9).font(.system(size: 17)).lineSpacing(6).focused($focused).accessibilityIdentifier("review.input")
                        if let imageData, let image = UIImage(data: imageData), step == 0 {
                            HStack { Image(uiImage: image).resizable().scaledToFill().frame(width: 55, height: 65).clipped().clipShape(RoundedRectangle(cornerRadius: 6)); Text(L("图片已附在这段经历里")).font(.caption2).foregroundStyle(Color.muted); Spacer(); Button { self.imageData = nil; photo = nil } label: { Image(systemName: "xmark.circle") }.accessibilityLabel(L("移除图片")) }
                        }
                        Divider()
                        HStack(spacing: 22) {
                            Button {
                                if speech.isRecording { speech.stop() } else { voicePrefix = input.isEmpty ? "" : input + "\n"; Task { await speech.start() } }
                            } label: { Image(systemName: speech.isRecording ? "stop.circle.fill" : "mic").foregroundStyle(speech.isRecording ? Color.red : Color.ink) }.accessibilityLabel(speech.isRecording ? L("停止录音") : L("语音输入"))
                            if step == 0 { PhotosPicker(selection: $photo, matching: .images) { Image(systemName: "photo") }.accessibilityLabel(L("添加图片或聊天截图")) }
                            Spacer()
                            Text(speech.isRecording ? L("正在聆听…") : L("只有你决定保存什么")).font(.system(size: 10)).foregroundStyle(Color.muted)
                        }.font(.system(size: 20, weight: .light))
                    }.surface()
                }
                if let personID, let person = store.person(personID) { Tag(text: L("与 \(person.name) 的一次经历")) }
                Button { advance() } label: {
                    HStack { if loading { ProgressView().tint(.inverse) }; Text(loading ? L("正在整理下一个问题…") : step == 4 ? L("整理这次经历") : L("继续")); if !loading { Image(systemName: "arrow.right") } }
                }.buttonStyle(PrimaryButtonStyle()).disabled(loading || (step == 0 && input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)).opacity(step == 0 && input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1).accessibilityIdentifier("review.next")
                if step > 0 {
                    Button(L("返回上一步，修正回答")) { back() }.font(.system(size: 12)).frame(maxWidth: .infinity).disabled(loading)
                }
                if step > 1 { Text(L("不确定也没关系，可以留空继续。")) .font(.caption2).foregroundStyle(Color.muted).frame(maxWidth: .infinity) }
            }.padding(25).frame(maxWidth: 680).frame(maxWidth: .infinity)
        }.scrollDismissesKeyboard(.interactively)
    }
    private var confirmation: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 23) {
                PageHeading(eyebrow: L("你的表达，你的故事"), title: L("这是你的意思吗？"), subtitle: L("以下内容来自你的回答，保存前可以直接修改。"))
                editable(L("发生了什么"), text: $facts)
                HStack { Text(L("当时的感受")).font(.subheadline); Spacer(); Picker(L("情绪"), selection: $emotion) { ForEach(Emotion.allCases) { Text($0.label).tag($0) } } }
                editable(L("我的解释 · 尚未核实"), text: $interpretation)
                editable(L("我在意的"), text: $need)
                editable(L("下一小步"), text: $action)
                Notice(text: L("仍然未知：他人的真实想法，以及尚未核实的信息。只凭这次记录，不对自己或他人下结论。"))
                if !store.data.people.isEmpty {
                    Text(L("关联人物 · 由你确认")).font(.subheadline.weight(.semibold))
                    FlowPeople(people: store.data.people, selected: $selectedPeople)
                }
                Toggle(L("将本次内容加入长期记忆"), isOn: $remember).font(.subheadline).disabled(!store.data.privacy.saveFacts && !store.data.privacy.saveFeelings)
                Text(store.data.privacy.saveFacts || store.data.privacy.saveFeelings ? L("仅保存你在隐私设置中允许的记忆类别。事件本身会保存到本机历史。") : L("长期记忆默认关闭，可在「我的 → 隐私与数据」开启。事件仍可单独保存在本机。")) .font(.caption).foregroundStyle(Color.muted).lineSpacing(4)
                Button {
                    let cleanFacts = facts.trimmingCharacters(in: .whitespacesAndNewlines)
                    let event = LifeEvent(title: String(cleanFacts.prefix(22)), facts: cleanFacts, feeling: emotion, interpretation: interpretation, need: need.trimmingCharacters(in: .whitespacesAndNewlines), nextStep: action, personIDs: Array(selectedPeople), imageData: imageData)
                    guard store.addEvent(event, remember: remember) else { error = store.persistenceError; return }
                    savedID = event.id
                    saved = true
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } label: { Text(L("确认并保存这次记录")) }.buttonStyle(PrimaryButtonStyle()).disabled(facts.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("review.save")
                Button(L("返回继续整理")) { step = 4; input = action }.font(.subheadline).frame(maxWidth: .infinity)
            }.padding(25).frame(maxWidth: 680).frame(maxWidth: .infinity)
        }
    }
    private var completion: some View {
        VStack(spacing: 25) {
            Spacer()
            Image(systemName: "checkmark").font(.system(size: 30, weight: .light)).frame(width: 80, height: 80).background(Color.sage.opacity(0.10), in: Circle()).foregroundStyle(Color.sage)
            Text(L("又多理解了自己一点。")).font(.system(size: 25, weight: .medium))
            Text(L("这段经历已收好。\n你随时可以回来，补充或修正它。")) .font(.subheadline).foregroundStyle(Color.muted).multilineTextAlignment(.center).lineSpacing(7)
            Spacer()
            if let savedID { NavigationLink { EventDetailView(eventID: savedID) } label: { Text(L("查看这次记录")) }.buttonStyle(PrimaryButtonStyle()) }
            Button(L("回到我的空间")) { dismiss() }.font(.subheadline).padding(.bottom, 20).accessibilityIdentifier("review.done")
        }.padding(25)
    }
    private func editable(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 10) { Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.crystal); TextField(L("可以留空"), text: text, axis: .vertical).font(.system(size: 16)).lineSpacing(5); Divider() }
    }
    private var api: CloudService? { try? CloudService(endpoint: store.data.privacy.endpoint.isEmpty ? CloudService.productionURL : store.data.privacy.endpoint) }
    private func advance() {
        guard !loading else { return }
        focused = false
        speech.stop()
        if step < 4, api?.signedIn != true { showAccount = true; return }
        let answer = step == 1 ? emotion.label : input.trimmingCharacters(in: .whitespacesAndNewlines)
        switch step { case 0: facts = answer; case 2: interpretation = answer; case 3: need = answer; case 4: action = answer; default: break }
        let values = [facts, emotion.label, interpretation, need, action]
        let labels = [L("事实"), L("感受"), L("个人解释"), L("在意点"), L("行动")]
        // Reconstruct on every attempt: retry/back must not duplicate or retain rejected answers.
        turns = (0...step).map { ReflectionTurn(role: "user", content: "\(labels[$0])：\(values[$0])") }
        guard step < 4, let api else { step += 1; input = ""; cloudQuestion = nil; return }
        loading = true
        requestTask = Task {
            do {
                let question = try await BackendReflectionService().nextQuestion(turns: turns, endpoint: api.baseURL)
                try Task.checkCancellation()
                cloudQuestion = question
                step += 1; input = ""
            } catch {
                if !Task.isCancelled { self.error = L("暂时没有收到回应。你的输入已保留，请再试一次。") }
            }
            if !Task.isCancelled { loading = false }
        }
    }
    private func back() {
        speech.stop()
        step = max(0, step - 1)
        input = [facts, "", interpretation, need, action][step]
        // Discard superseded context so rejected answers cannot reach subsequent requests.
        turns = []
        cloudQuestion = nil
        let values = [facts, emotion.label, interpretation, need, action]
        for index in 0..<step { turns.append(ReflectionTurn(role: "user", content: values[index])) }
    }
}

struct FlowPeople: View {
    let people: [Person]
    @Binding var selected: Set<UUID>
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], alignment: .leading, spacing: 10) {
            ForEach(people) { person in
                Button {
                    if selected.contains(person.id) { selected.remove(person.id) } else { selected.insert(person.id) }
                } label: { Text(person.name).font(.system(size: 13)).padding(.vertical, 11).frame(maxWidth: .infinity).background(selected.contains(person.id) ? Color.ink : Color.surface, in: Capsule()).foregroundStyle(selected.contains(person.id) ? Color.inverse : Color.ink) }
            }
        }
    }
}

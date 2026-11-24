import SwiftUI
import PhotosUI

struct PersonEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    private let isNew: Bool
    @State private var draft: Person
    @FocusState private var writing: Bool
    @State private var photo: PhotosPickerItem?
    @State private var photoLoading = false
    @State private var error: String?
    @State private var hasBirthday: Bool
    @State private var month: Int
    @State private var day: Int
    @State private var year: String
    @State private var hasCloseness: Bool
    @State private var closeness: Double
    init(existing: Person? = nil) {
        let person = existing ?? Person(name: "", group: .uncategorized)
        isNew = existing == nil; _draft = State(initialValue: person)
        _hasBirthday = State(initialValue: person.birthday != nil)
        _month = State(initialValue: person.birthday?.month ?? 1)
        _day = State(initialValue: person.birthday?.day ?? 1)
        _year = State(initialValue: person.birthday?.year.map(String.init) ?? "")
        _hasCloseness = State(initialValue: person.closeness != nil)
        _closeness = State(initialValue: Double(person.closeness?.rawValue ?? 2))
    }
    private var birthday: PersonBirthday? { hasBirthday ? PersonBirthday(month: month, day: day, year: Int(year)) : nil }
    private var validBirthday: Bool {
        !hasBirthday || (birthday?.isValid == true && (year.isEmpty || (Int(year).map { (1...Calendar.current.component(.year, from: Date())).contains($0) } ?? false)))
    }
    private var valid: Bool { !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !photoLoading && validBirthday }
    private func text(_ key: WritableKeyPath<Person, String?>) -> Binding<String> { Binding(get: { draft[keyPath: key] ?? "" }, set: { draft[keyPath: key] = $0 }) }
    var body: some View {
        let photoTitle = L("选择头像")
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 20) {
                        PersonAvatar(person: draft, size: 72)
                        VStack(alignment: .leading, spacing: 12) {
                            PhotosPicker(selection: $photo, matching: .images) { Label(photoTitle, systemImage: "photo") }.accessibilityIdentifier("person.photo")
                            if draft.avatarData != nil { Button(L("移除头像"), role: .destructive) { draft.avatarData = nil; photo = nil; photoLoading = false } }
                            if photoLoading { ProgressView() }
                        }
                    }.padding(.vertical, 8)
                    TextField(L("称呼或昵称"), text: $draft.name).focused($writing).accessibilityIdentifier("person.name")
                    Picker(L("关系分类"), selection: $draft.group) { ForEach(RelationGroup.allCases) { Text($0.label).tag($0) } }.accessibilityIdentifier("person.group")
                    TextField(L("公司、学校或组织（可选）"), text: text(\.organization)).focused($writing).accessibilityIdentifier("person.organization")
                } header: { Text(L("人物信息")) }
                Section {
                    Toggle(L("标注亲密程度"), isOn: $hasCloseness).accessibilityIdentifier("person.hasCloseness")
                    if hasCloseness {
                        HStack { Text(ConnectionCloseness(rawValue: Int(closeness))?.label ?? ""); Spacer(); Circle().fill(ConnectionCloseness(rawValue: Int(closeness))?.color ?? Color.muted).frame(width: 12, height: 12) }
                        Slider(value: $closeness, in: 0...4, step: 1).tint(ConnectionCloseness(rawValue: Int(closeness))?.color ?? Color.ink).accessibilityLabel(L("亲密程度")).accessibilityIdentifier("person.closeness")
                        HStack { Text(L("冰蓝 · 较淡")); Spacer(); Text(L("暖粉 · 亲密")) }.font(.caption).foregroundStyle(Color.muted)
                    }
                } header: { Text(L("此刻的亲密程度")) } footer: { Text(L("由你标注，也可以随时调整。颜色表示你的感受，不是系统评分。")) }
                Section {
                    Toggle(L("记录生日"), isOn: $hasBirthday).accessibilityIdentifier("person.hasBirthday")
                    if hasBirthday {
                        Picker(L("月份"), selection: $month) { ForEach(1...12, id: \.self) { Text(String($0)).tag($0) } }.accessibilityIdentifier("person.month")
                        Picker(L("日期"), selection: $day) { ForEach(1...31, id: \.self) { Text(String($0)).tag($0) } }.accessibilityIdentifier("person.day")
                        TextField(L("出生年份（可留空）"), text: $year).keyboardType(.numberPad).focused($writing).accessibilityIdentifier("person.year")
                        if let sign = birthday?.zodiac { LabeledContent(L("星座"), value: sign) }
                        if !validBirthday { Text(L("请检查生日的月、日和年份。")) .font(.caption).foregroundStyle(Color.muted) }
                    }
                } header: { Text(L("生日与星座")) } footer: { Text(L("只知道月日也可以。星座按常见公历日期划分，仅作资料展示。")) }
                Section(L("关于这个人")) {
                    TextField(L("喜欢的事物"), text: text(\.likes), axis: .vertical).lineLimit(2...5).focused($writing).accessibilityIdentifier("person.likes")
                    TextField(L("不喜欢或需要避开的事物"), text: text(\.dislikes), axis: .vertical).lineLimit(2...5).focused($writing).accessibilityIdentifier("person.dislikes")
                    TextField(L("值得记住的小事或相处习惯"), text: text(\.careNotes), axis: .vertical).lineLimit(2...5).focused($writing).accessibilityIdentifier("person.careNotes")
                    TextField(L("我对这段关系的期待（可选）"), text: $draft.note, axis: .vertical).lineLimit(2...5).focused($writing)
                }
                if let error { Text(error).font(.caption).foregroundStyle(Color.muted) }
                Section { Text(L("这些资料保存在本机，由你填写与修改。不会写回系统通讯录。")) .font(.caption).foregroundStyle(Color.muted) }
            }.scrollDismissesKeyboard(.interactively).navigationTitle(isNew ? L("添加关系") : L("编辑人物")).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) { Spacer(); Button(L("完成输入")) { writing = false }.accessibilityIdentifier("person.keyboard.done") }
                    ToolbarItem(placement: .cancellationAction) { Button(L("取消")) { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button(L("保存")) { save() }.disabled(!valid).accessibilityIdentifier("person.save") }
                }
                .task(id: photo) {
                    guard let photo else { return }; photoLoading = true
                    defer { if self.photo == photo { photoLoading = false } }
                    do {
                        guard let data = try await photo.loadTransferable(type: Data.self), let compact = ProfilePhoto.compact(data) else { throw CocoaError(.fileReadCorruptFile) }
                        try Task.checkCancellation(); draft.avatarData = compact
                    } catch { if !Task.isCancelled { self.error = L("头像暂时无法读取，请重新选择。") } }
                }
        }
    }
    private func save() {
        guard valid else { return }
        draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.birthday = birthday; draft.closeness = hasCloseness ? ConnectionCloseness(rawValue: Int(closeness)) : nil
        if isNew ? store.addPerson(draft) : store.updatePerson(draft) { dismiss() }
        else { error = store.persistenceError }
    }
}

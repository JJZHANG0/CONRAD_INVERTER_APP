import SwiftUI
import ContactsUI

struct ContactImportView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var picking = false
    @State private var processing = false
    @State private var candidates: [Person] = []
    @State private var selected: Set<UUID> = []
    @State private var group: RelationGroup = .uncategorized
    @State private var error: String?
    let completion: (ContactImportResult) -> Void
    private var known: Set<String> { Set(store.data.people.compactMap(\.contactIdentifier)) }
    private func imported(_ person: Person) -> Bool { person.contactIdentifier.map { known.contains($0) } ?? false }
    var body: some View {
        NavigationStack {
            Group {
                if processing { ProgressView(L("正在准备联系人…")).frame(maxWidth: .infinity, maxHeight: .infinity) }
                else if candidates.isEmpty {
                    VStack(spacing: 24) {
                        Image(systemName: "person.crop.rectangle.stack").font(.system(size: 54, weight: .ultraLight))
                        Text(L("把熟悉的人，带到这里。")).font(.title2).multilineTextAlignment(.center)
                        Text(L("选择想导入的联系人，确认后保存姓名、头像、生日与组织信息。你可以稍后补充分类和亲密程度。")) .font(.subheadline).foregroundStyle(Color.muted).multilineTextAlignment(.center).lineSpacing(6)
                        Button { choose() } label: { Text(L("选择联系人")) }.buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("contacts.choose")
                    }.padding(32).frame(maxWidth: 500).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            Picker(L("导入后的分类"), selection: $group) { ForEach(RelationGroup.allCases) { Text($0.label).tag($0) } }.accessibilityIdentifier("contacts.group")
                        } footer: { Text(L("默认归入未分类。导入后可在人物档案中分别调整。")) }
                        Section {
                            ForEach(candidates) { person in
                                Button {
                                    if selected.contains(person.id) { selected.remove(person.id) } else { selected.insert(person.id) }
                                } label: {
                                    HStack(spacing: 14) {
                                        PersonAvatar(person: person)
                                        VStack(alignment: .leading, spacing: 5) { Text(person.name).foregroundStyle(Color.ink); Text(imported(person) ? L("已导入，保留现有档案") : person.birthday?.formatted ?? L("生日可稍后补充")).font(.caption).foregroundStyle(Color.muted) }
                                        Spacer(); Image(systemName: selected.contains(person.id) && !imported(person) ? "checkmark.circle.fill" : "circle").foregroundStyle(Color.ink)
                                    }
                                }.buttonStyle(.plain).disabled(imported(person)).accessibilityIdentifier("contacts.row.\(person.name)")
                            }
                        } header: { Text(L("确认导入的人物")) } footer: { Text(L("相同联系人不会重复添加，也不会覆盖你已修改的资料。")) }
                        Button(L("重新选择")) { choose() }
                        if let error { Text(error).font(.caption).foregroundStyle(Color.muted) }
                    }
                }
            }.background(Color.paper).navigationTitle(L("导入通讯录")).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(L("取消")) { dismiss() } }
                    if !candidates.isEmpty {
                        ToolbarItem(placement: .confirmationAction) { Button(L("导入") + " (\(selected.count))") { commit() }.disabled(selected.isEmpty || processing).accessibilityIdentifier("contacts.import") }
                    }
                }
                .sheet(isPresented: $picking) { SystemContactPicker { contacts in picking = false; prepare(contacts) } cancel: { picking = false } }
        }
    }
    private func choose() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting") && ProcessInfo.processInfo.arguments.contains("--contacts-fixture") { prepare(ContactImportFixture.contacts()); return }
        #endif
        picking = true
    }
    private func prepare(_ contacts: [CNContact]) {
        guard !contacts.isEmpty else { return }
        processing = true; error = nil
        Task { @MainActor in
            var values: [Person] = []; var identifiers = Set<String>()
            for contact in contacts where identifiers.insert(contact.identifier).inserted {
                values.append(ContactImport.person(from: contact)); await Task.yield()
            }
            candidates = values; selected = Set(values.filter { !imported($0) }.map(\.id)); processing = false
        }
    }
    private func commit() {
        let people = candidates.filter { selected.contains($0.id) && !imported($0) }.map { value in var p = value; p.group = group; return p }
        if let result = store.importContacts(people) { completion(result); dismiss() }
        else { error = store.persistenceError }
    }
}
private struct SystemContactPicker: UIViewControllerRepresentable {
    let select: ([CNContact]) -> Void
    let cancel: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(select: select, cancel: cancel) }
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController(); picker.delegate = context.coordinator
        picker.displayedPropertyKeys = [CNContactBirthdayKey, CNContactOrganizationNameKey]
        picker.view.accessibilityIdentifier = "contacts.systemPicker"
        return picker
    }
    func updateUIViewController(_ controller: CNContactPickerViewController, context: Context) {}
    final class Coordinator: NSObject, CNContactPickerDelegate {
        let select: ([CNContact]) -> Void; let cancel: () -> Void
        init(select: @escaping ([CNContact]) -> Void, cancel: @escaping () -> Void) { self.select = select; self.cancel = cancel }
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) { select(contacts) }
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) { cancel() }
    }
}

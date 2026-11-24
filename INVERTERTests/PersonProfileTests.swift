import Foundation
import Contacts
import UIKit
import Testing
@testable import INVERTER

@MainActor struct PersonProfileTests {
    private func store() -> (AppStore, URL) {
        let url = URL.temporaryDirectory.appending(path: "people-\(UUID()).json")
        let store = AppStore(fileURL: url); store.data.showDemo = false
        return (store, url)
    }
    @Test func birthdayValidationDoesNotInventMissingYears() throws {
        #expect(PersonBirthday(month: 2, day: 29).isValid)
        #expect(!PersonBirthday(month: 2, day: 29, year: 2025).isValid)
        #expect(PersonBirthday(month: 2, day: 29, year: 2024).isValid)
        #expect(!PersonBirthday(month: 4, day: 31).isValid)
        #expect(!PersonBirthday(month: 0, day: 1).isValid)
        #expect(PersonBirthday(month: 3, day: 20).zodiac == L("双鱼座"))
        #expect(PersonBirthday(month: 3, day: 21).zodiac == L("白羊座"))
        #expect(PersonBirthday(month: 12, day: 22).zodiac == L("摩羯座"))
        #expect(PersonBirthday(month: 1, day: 20).zodiac == L("水瓶座"))
        let roundtrip = try JSONDecoder().decode(PersonBirthday.self, from: JSONEncoder().encode(PersonBirthday(month: 5, day: 1)))
        #expect(roundtrip.year == nil)
    }
    @Test func oldPeopleDecodeWithUnknownClosenessAndOptionalProfile() throws {
        let person = Person(name: "An existing friend", group: .friend)
        let data = try JSONEncoder().encode(person)
        let old = try JSONDecoder().decode(Person.self, from: data)
        #expect(old.birthday == nil && old.closeness == nil && old.avatarData == nil && old.contactIdentifier == nil)
        let (store, url) = store(); defer { try? FileManager.default.removeItem(at: url) }
        #expect(store.addPerson(old))
        var changed = old; changed.birthday = PersonBirthday(month: 3, day: 21); changed.likes = "Coffee"; changed.dislikes = "Loud rooms"; changed.careNotes = "Ask ahead"; changed.closeness = .intimate; changed.group = .colleague
        #expect(store.updatePerson(changed))
        let reopened = AppStore(fileURL: url)
        #expect(reopened.person(old.id) == changed)
        #expect(reopened.data.relationships.first?.personID == old.id)
        #expect(reopened.data.relationships.first?.description == RelationGroup.colleague.rawValue)
    }
    @Test func pickedContactsImportOnlySelectedProfileFieldsAndCompactPhoto() throws {
        let contact = CNMutableContact(); contact.givenName = "Alex"; contact.familyName = "Preview"; contact.organizationName = "Example"
        contact.birthday = DateComponents(month: 2, day: 29)
        contact.emailAddresses = [CNLabeledValue(label: CNLabelHome, value: "private@example.com" as NSString)]
        contact.imageData = UIGraphicsImageRenderer(size: CGSize(width: 900, height: 500)).image { _ in UIColor.gray.setFill(); UIBezierPath(rect: CGRect(x: 0, y: 0, width: 900, height: 500)).fill() }.pngData()
        let person = ContactImport.person(from: contact)
        #expect(person.name.contains("Alex")); #expect(person.group == .uncategorized && person.closeness == nil)
        #expect(person.birthday?.year == nil && person.birthday?.day == 29)
        let avatar = try #require(person.avatarData)
        let image = try #require(UIImage(data: avatar))
        #expect(image.size == CGSize(width: 320, height: 320))
        let serialized = String(data: try JSONEncoder().encode(person), encoding: .utf8)!
        #expect(!serialized.contains("private@example.com"))
    }
    @Test func repeatedImportDoesNotDuplicateOrOverwriteEditedProfiles() throws {
        let (store, url) = store(); defer { try? FileManager.default.removeItem(at: url) }
        let source = CNMutableContact(); source.givenName = "Same name"
        let other = CNMutableContact(); other.givenName = "Same name"
        let first = ContactImport.person(from: source)
        #expect(store.importContacts([first, first])?.added == 1)
        var edited = try #require(store.person(first.id)); edited.group = .family; edited.likes = "My own note"; edited.closeness = .close
        #expect(store.updatePerson(edited))
        let position = edited.spherePosition
        let result = try #require(store.importContacts([ContactImport.person(from: source), ContactImport.person(from: other)]))
        #expect(result.added == 1 && result.skipped == 1)
        #expect(store.data.people.count == 2 && store.data.relationships.count == 2)
        #expect(store.person(first.id)?.likes == "My own note" && store.person(first.id)?.group == .family)
        #expect(store.person(first.id)?.spherePosition == position)
        #expect(AppStore(fileURL: url).data.people.count == 2)
    }
    @Test func failedImportsAndProfileEditsRollBackAtomically() throws {
        let file = URL.temporaryDirectory.appending(path: "blocked-people-\(UUID())")
        try Data().write(to: file); defer { try? FileManager.default.removeItem(at: file) }
        let store = AppStore(fileURL: file.appending(path: "data.json"))
        var person = Person(name: "Original", group: .uncategorized); person.contactIdentifier = "synthetic-only"
        #expect(store.importContacts([person]) == nil)
        #expect(store.data.people.isEmpty && store.data.relationships.isEmpty)
        #expect(!store.addPerson(person)); #expect(store.data.people.isEmpty)
        store.data.people = [person]; person.likes = "A changed note"
        #expect(!store.updatePerson(person)); #expect(store.data.people[0].likes == nil)
    }
    @Test func batchedSphereLayoutPreservesOldNodesAndDistinctNewPositions() {
        var people = (0..<50).map { Person(name: "P\($0)", group: .uncategorized) }
        let before = RelationshipSphereLayout.positions(for: people)
        for i in people.indices { people[i].spherePosition = before[people[i].id] }
        people += (50..<250).map { Person(name: "P\($0)", group: .uncategorized) }
        let after = RelationshipSphereLayout.positions(for: people)
        #expect(after.count == 250 && Set(after.values).count == 250)
        #expect(before.allSatisfy { after[$0.key] == $0.value })
        #expect(after.values.allSatisfy { $0.isValid })
    }
}

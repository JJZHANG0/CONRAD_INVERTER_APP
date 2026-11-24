import Contacts
import UIKit

@MainActor enum ContactImport {
    static func person(from contact: CNContact) -> Person {
        let name = contact.areKeysAvailable([CNContactFormatter.descriptorForRequiredKeys(for: .fullName)]) ? CNContactFormatter.string(from: contact, style: .fullName) : nil
        let organization = contact.isKeyAvailable(CNContactOrganizationNameKey) ? contact.organizationName : ""
        var person = Person(name: (name?.isEmpty == false ? name : nil) ?? (organization.isEmpty ? L("未命名联系人") : organization), group: .uncategorized)
        person.contactIdentifier = contact.identifier
        person.organization = organization.isEmpty ? nil : organization
        if contact.isKeyAvailable(CNContactBirthdayKey), let components = contact.birthday, let month = components.month, let day = components.day {
            let year = components.year.flatMap { (1...9999).contains($0) ? $0 : nil }
            let birthday = PersonBirthday(month: month, day: day, year: year)
            if birthday.isValid { person.birthday = birthday }
        }
        let thumbnail = contact.isKeyAvailable(CNContactThumbnailImageDataKey) ? contact.thumbnailImageData : nil
        let original = thumbnail == nil && contact.isKeyAvailable(CNContactImageDataKey) ? contact.imageData : nil
        if let data = thumbnail ?? original { person.avatarData = ProfilePhoto.compact(data) }
        return person
    }
}
struct ContactImportResult { let added: Int; let skipped: Int }
extension AppStore {
    /// One atomic save; a repeated contact never overwrites hand-edited profile data.
    func importContacts(_ candidates: [Person]) -> ContactImportResult? {
        let previous = data
        var known = Set(data.people.compactMap(\.contactIdentifier))
        var added = 0
        for var person in candidates {
            guard let identifier = person.contactIdentifier, !identifier.isEmpty, known.insert(identifier).inserted else { continue }
            person.isDemo = false
            data.people.append(person)
            data.relationships.append(Relationship(personID: person.id, description: person.group.rawValue))
            added += 1
        }
        if added == 0 { return ContactImportResult(added: 0, skipped: candidates.count) }
        let positions = RelationshipSphereLayout.positions(for: data.people)
        for i in data.people.indices { data.people[i].spherePosition = positions[data.people[i].id] }
        guard save() else { data = previous; return nil }
        return ContactImportResult(added: added, skipped: candidates.count - added)
    }
}
#if DEBUG
@MainActor enum ContactImportFixture {
    static func contacts() -> [CNContact] { savedContacts }
    private static let savedContacts: [CNContact] = (0..<3).map { index in
            let contact = CNMutableContact()
            contact.givenName = ["Alex", "Jamie", "Taylor"][index]; contact.familyName = "Preview"
            contact.organizationName = "Example Studio"
            contact.birthday = DateComponents(month: 3 + index, day: 21)
            let image = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 120)).image { context in
                UIColor(white: 0.85, alpha: 1).setFill(); context.fill(CGRect(x: 0, y: 0, width: 120, height: 120))
                UIColor.darkGray.setFill(); context.cgContext.fillEllipse(in: CGRect(x: 43, y: 22, width: 34, height: 34)); context.cgContext.fillEllipse(in: CGRect(x: 22, y: 65, width: 76, height: 76))
            }
            contact.imageData = image.jpegData(compressionQuality: 0.8)
            return contact
        }
}
#endif

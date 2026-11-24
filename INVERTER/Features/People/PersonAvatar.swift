import SwiftUI
import UIKit

struct PersonAvatar: View {
    let person: Person
    var size: CGFloat = 44
    var body: some View {
        Group {
            if let data = person.avatarData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Text(person.initials).font(.system(size: size * 0.37, weight: .medium)).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.surface)
            }
        }.frame(width: size, height: size).clipShape(Circle())
            .overlay(Circle().stroke(person.closeness?.color ?? Color.line, lineWidth: person.closeness == nil ? 1 : 2))
            .accessibilityHidden(true)
    }
}
@MainActor enum ProfilePhoto {
    static func compact(_ data: Data) -> Data? {
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else { return nil }
        let side: CGFloat = 320
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let scale = side / min(image.size.width, image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            image.draw(in: CGRect(x: (side-size.width)/2, y: (side-size.height)/2, width: size.width, height: size.height))
        }.jpegData(compressionQuality: 0.82)
    }
}

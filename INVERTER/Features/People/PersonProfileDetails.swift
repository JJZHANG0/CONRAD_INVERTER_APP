import SwiftUI

struct PersonProfileDetails: View {
    let person: Person
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label(L("此刻的亲密程度"), systemImage: "heart").font(.caption).foregroundStyle(Color.muted)
                Spacer()
                HStack(spacing: 7) { Circle().fill(person.closeness?.color ?? Color.line).frame(width: 8, height: 8); Text(person.closeness?.label ?? L("未标注")).font(.subheadline) }
            }
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 9) { Label(L("生日"), systemImage: "gift").font(.caption).foregroundStyle(Color.muted); Text(person.birthday?.formatted ?? L("待补充")).font(.subheadline) }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 9) { Label(L("星座"), systemImage: "sparkles").font(.caption).foregroundStyle(Color.muted); Text(person.birthday?.zodiac ?? "—").font(.subheadline) }.frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            detail(L("喜欢的事物"), value: person.likes, icon: "heart.text.clipboard")
            detail(L("不喜欢的事物"), value: person.dislikes, icon: "minus.circle")
            detail(L("值得记住的小事"), value: person.careNotes, icon: "bookmark")
        }.surface().accessibilityIdentifier("person.profileDetails")
    }
    private func detail(_ title: String, value: String?, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon).font(.caption).foregroundStyle(Color.muted)
            Text(value?.isEmpty == false ? value! : L("待补充")).font(.system(size: 15)).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
